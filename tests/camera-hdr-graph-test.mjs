import fs from 'node:fs';
import assert from 'node:assert/strict';
const graph=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
const nodes=graph.NodesList.Node, links=graph.PortLinkages.Link;
const names=new Set(nodes.map(n=>n.NodeInstance));
assert(names.has('GainMapInstance0'), 'HDR gainmap producer is missing');
assert(names.has('jpegrAggrInstance'), 'JPEG HDR packager is missing');
assert(!names.has('HeicInstance1'), 'Known orphan auxiliary HEIF branch remains');
assert(!names.has('JpegInstanceFinal1') && !names.has('jpegrAggrInstanceSharp'),
  'JPEG-only sharp-image branch can target a disabled HDR packager in HEIF mode');
const anchor=nodes.find(n=>n.NodeInstance==='BayerRaw2YuvInstanceGainmapAnchor');
assert(anchor?.NodeProperty?.some(p=>p.NodePropertyName==='InputFormatNegotiationNeeded'
  && p.NodePropertyValue===true), 'Gainmap anchor cannot negotiate camera-specific RAW format');
const input=links.find(l=>l.DstPort.NodeInstance===anchor.NodeInstance);
assert.equal(input?.DstPort.PortFormat,'RAW10','Packed RAW10 fallback is missing');
for(const link of links) for(const end of [link.SrcPort,link.DstPort]) {
  assert(names.has(end.NodeInstance)||/^(Source|Sink)Buffer\d+$/.test(end.NodeInstance),
    `Dangling HDR stage ${end.NodeInstance}`);
}
const reach=new Set(['GainMapInstance0']);
for(const n of reach) for(const l of links) if(l.SrcPort.NodeInstance===n) reach.add(l.DstPort.NodeInstance);
assert(reach.has('jpegrAggrInstance')&&reach.has('HeifEditInstance')&&reach.has('SinkBuffer0'),
  'Gainmap cannot reach both image packagers and the saved-image sink');
console.log(`PASS: HDR graph (${nodes.length} nodes, ${links.length} links)`);
