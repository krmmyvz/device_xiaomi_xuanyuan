import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

export function checkJpegGraph(graph) {
  const nodes = graph.NodesList.Node;
  const links = graph.PortLinkages.Link;
  const extended = nodes.filter(n => /heif|heic|gainmap|jpegr/i.test(n.NodeName));
  if (extended.length) throw new Error('Extended HDR/HEIF nodes remain');
  const names = new Set(nodes.map(n => n.NodeInstance));
  const external = n => /^(Source|Sink)Buffer\d+$/.test(n);
  for (const link of links) for (const end of [link.SrcPort, link.DstPort]) {
    if (!names.has(end.NodeInstance) && !external(end.NodeInstance)) {
      throw new Error(`Dangling node: ${end.NodeInstance}`);
    }
  }
  const reaches = (start, target) => {
    const seen = new Set([start]);
    for (const n of seen) for (const l of links) {
      if (l.SrcPort.NodeInstance === n) seen.add(l.DstPort.NodeInstance);
    }
    return seen.has(target);
  };
  if (!reaches('SourceBuffer0', 'MfnrInstance0') ||
      !reaches('MfnrInstance0', 'JpegInstanceFinal') ||
      !reaches('JpegInstanceFinal', 'SinkBuffer0')) {
    throw new Error('Processed full JPEG path is incomplete');
  }
  return {nodes: nodes.length, links: links.length};
}

export function makeJpegGraph(original) {
  const graph = structuredClone(original);
  const excluded = new Set(graph.NodesList.Node.filter(n =>
    /heif|heic|gainmap|jpegr/i.test(n.NodeName) ||
    ['JpegInstanceFinal1', 'swjpegInstance1'].includes(n.NodeInstance)
  ).map(n => n.NodeInstance));
  let links = graph.PortLinkages.Link.filter(l =>
    !excluded.has(l.SrcPort.NodeInstance) && !excluded.has(l.DstPort.NodeInstance));
  const sink = original.PortLinkages.Link.find(l =>
    l.SrcPort.NodeInstance === 'HeifEditInstance' &&
    l.DstPort.NodeInstance === 'SinkBuffer0');
  if (!sink) throw new Error('Cannot locate the original image sink');
  links.push({SrcPort: {PortId: 0, NodeInstance: 'JpegInstanceFinal', PortFormat: 'BLOB'},
    DstPort: structuredClone(sink.DstPort)});
  const needed = new Set(['SinkBuffer0']);
  for (const n of needed) for (const l of links) {
    if (l.DstPort.NodeInstance === n) needed.add(l.SrcPort.NodeInstance);
  }
  graph.NodesList.Node = graph.NodesList.Node.filter(n =>
    needed.has(n.NodeInstance) && !excluded.has(n.NodeInstance));
  graph.PortLinkages.Link = links.filter(l =>
    needed.has(l.SrcPort.NodeInstance) && needed.has(l.DstPort.NodeInstance));
  checkJpegGraph(graph);
  return graph;
}

export function makeSdrGraph(original) {
  const graph = structuredClone(original);
  const excluded = new Set(graph.NodesList.Node.filter(n =>
    /gainmap|jpegr/i.test(n.NodeName) ||
    ['JpegInstanceFinal1', 'swjpegInstance1', 'HeicInstance1',
      'yuv2HeicInstance1'].includes(n.NodeInstance)
  ).map(n => n.NodeInstance));
  let links = graph.PortLinkages.Link.filter(l =>
    !excluded.has(l.SrcPort.NodeInstance) && !excluded.has(l.DstPort.NodeInstance));
  const source = original.PortLinkages.Link.find(l =>
    l.SrcPort.NodeInstance === 'yuv2HeicInstance' &&
    l.DstPort.NodeInstance === 'jpegrAggrInstance');
  const target = original.PortLinkages.Link.find(l =>
    l.SrcPort.NodeInstance === 'jpegrAggrInstance' &&
    l.DstPort.NodeInstance === 'HeifEditInstance');
  if (!source || !target) throw new Error('Cannot locate primary HEIF packaging path');
  links.push({SrcPort: structuredClone(source.SrcPort),
    DstPort: structuredClone(target.DstPort)});
  const metadataSource = original.PortLinkages.Link.find(l =>
    l.SrcPort.NodeInstance === 'HeicInstance0' && l.SrcPort.PortId === 1 &&
    l.DstPort.NodeInstance === 'jpegrAggrInstanceForHeic');
  const metadataTarget = original.PortLinkages.Link.find(l =>
    l.SrcPort.NodeInstance === 'jpegrAggrInstanceForHeic' &&
    l.DstPort.NodeInstance === 'yuv2HeicInstance' && l.DstPort.PortId === 1);
  if (!metadataSource || !metadataTarget) throw new Error('Cannot locate HEIF metadata input');
  links.push({SrcPort: structuredClone(metadataSource.SrcPort),
    DstPort: structuredClone(metadataTarget.DstPort)});
  const needed = new Set(['SinkBuffer0']);
  for (const n of needed) for (const l of links) {
    if (l.DstPort.NodeInstance === n) needed.add(l.SrcPort.NodeInstance);
  }
  graph.NodesList.Node = graph.NodesList.Node.filter(n =>
    needed.has(n.NodeInstance) && !excluded.has(n.NodeInstance));
  graph.PortLinkages.Link = links.filter(l =>
    needed.has(l.SrcPort.NodeInstance) && needed.has(l.DstPort.NodeInstance));
  return graph;
}

export function makeHdrGraph(original) {
  const graph=structuredClone(original);
  const excluded=new Set(['HeicInstance1','yuv2HeicInstance1',
    'JpegInstanceFinal1','jpegrAggrInstanceSharp','GainMapPostProcInstanceSharp']);
  graph.NodesList.Node=graph.NodesList.Node.filter(n=>!excluded.has(n.NodeInstance));
  graph.PortLinkages.Link=graph.PortLinkages.Link.filter(l=>
    !excluded.has(l.SrcPort.NodeInstance)&&!excluded.has(l.DstPort.NodeInstance));
  const anchor=graph.NodesList.Node.find(n=>n.NodeInstance==='BayerRaw2YuvInstanceGainmapAnchor');
  if(!anchor) throw new Error('Missing stock gainmap anchor');
  anchor.NodeProperty.push(
    {NodePropertyName:'InputFormatNegotiationNeeded',NodePropertyValue:true},
    {NodePropertyName:'NegotiationInputFormatInfo',NodePropertyValue:'CAM_COMBMODE_REAR_WIDE:RAW16'});
  const input=graph.PortLinkages.Link.find(l=>l.DstPort.NodeInstance===anchor.NodeInstance);
  input.SrcPort.PortFormat='RAW10';
  input.DstPort.PortFormat='RAW10';
  return graph;
}

if (path.resolve(process.argv[1] || '') === fileURLToPath(import.meta.url)) {
  const [mode, source, dest] = process.argv.slice(2);
  const original = JSON.parse(fs.readFileSync(source, 'utf8'));
  if (mode === '--check') console.log(checkJpegGraph(original));
  else if (mode === '--generate-hdr' && dest) {
    const graph=makeHdrGraph(original);
    fs.writeFileSync(dest,JSON.stringify(graph,null,2)+'\n');
    console.log({nodes:graph.NodesList.Node.length,links:graph.PortLinkages.Link.length});
  } else if (mode === '--generate-sdr' && dest) {
    const graph = makeSdrGraph(original);
    fs.writeFileSync(dest, JSON.stringify(graph, null, 2) + '\n');
    console.log({nodes:graph.NodesList.Node.length, links:graph.PortLinkages.Link.length});
  } else if (mode === '--generate' && dest) {
    const graph = makeJpegGraph(original);
    fs.writeFileSync(dest, JSON.stringify(graph, null, 2) + '\n');
    console.log(checkJpegGraph(graph));
  } else throw new Error('Use --check INPUT or --generate INPUT OUTPUT');
}
