import fs from 'node:fs';
import assert from 'node:assert/strict';
const graph = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const nodes = graph.NodesList.Node;
const links = graph.PortLinkages.Link;
const named = new Set(nodes.map(n => n.NodeInstance));
for (const n of ['MfnrInstance0', 'JpegInstanceFinal', 'HeicInstance0',
  'yuv2HeicInstance', 'HeifEditInstance']) {
  assert(named.has(n), `Missing processed SDR JPEG/HEIF stage: ${n}`);
}
assert(!nodes.some(n => /gainmap|jpegr/i.test(n.NodeName)),
  'HDR gainmap/JPEG-R branch must stay disabled');
assert(!named.has('HeicInstance1'), 'Orphan auxiliary HEIF sharp-image branch remains');
assert(links.some(l => l.SrcPort.NodeInstance === 'HeicInstance0' &&
  l.SrcPort.PortId === 1 && l.DstPort.NodeInstance === 'yuv2HeicInstance' &&
  l.DstPort.PortId === 1), 'HEIF writer is missing encoded-image metadata input 1');
for (const link of links) for (const end of [link.SrcPort, link.DstPort]) {
  assert(named.has(end.NodeInstance) || /^(Source|Sink)Buffer\d+$/.test(end.NodeInstance),
    `Dangling stage ${end.NodeInstance}`);
}
const reachable = new Set(['MfnrInstance0']);
for (const node of reachable) for (const link of links) {
  if (link.SrcPort.NodeInstance === node) reachable.add(link.DstPort.NodeInstance);
}
for (const node of ['JpegInstanceFinal','HeifEditInstance','SinkBuffer0']) {
  assert(reachable.has(node), `Processed image cannot reach ${node}`);
}
console.log(`PASS: processed SDR JPEG/HEIF graph (${nodes.length} nodes, ${links.length} links)`);
