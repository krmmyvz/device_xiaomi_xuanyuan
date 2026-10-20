# JPEG UltraHDR, 2026-10-10

Scope: rear-camera JPEG UltraHDR gainmaps now work. HEIF still saves a full
SDR image; Android does not recognize its output as gainmap HDR. Do not claim
HEIF HDR support or infer HDR support for every lens/mode from these tests.

The working JPEG/HEIF SDR setup remains available in satsnapshot-sdr.json.
The installed graph is now configs/camera/satsnapshot-hdr-compatible.json.
Stock303 executable/shared-library instructions are unchanged.

Changes:
- Restore gainmap and JPEG-R aggregation stages with ultrahdr.enable=1.
- Gainmap RAW anchor uses packed RAW10 as its fallback, with the stock-style
  InputFormatNegotiationNeeded/NegotiationInputFormatInfo mechanism retaining
  CAM_COMBMODE_REAR_WIDE:RAW16 negotiation. This corrects the previously observed
  RAW10-vs-RAW16 mismatch without changing pixel-buffer format labels.
- Exclude both auxiliary HEIF sharp-image and JPEG sharp-image branches. The
  first HDR candidate retained JPEG sharp output and crashed in HEIF mode by
  referencing a disabled jpegrAggrInstance. The final graph removes these
  format-specific orphan paths but keeps primary codecs and gainmap processing.

Final graph: 45 nodes, 64 links. The graph test initially rejected SDR (no
gainmap) and the first candidate (orphan JPEG sharp branch); final checks pass.
Regeneration: scripts/camera-jpeg-graph.mjs --generate-hdr STOCK_JSON OUTPUT.
Structural regression test: tests/camera-hdr-graph-test.mjs GRAPH_JSON.

Runtime verification using the final graph:
- IMG_20261010_124950.jpg: 21518284 bytes, 3072x4550, capture at 12:49:50.167,
  CAPTURE-END at 12:49:50.945 (~0.78s), fullImageReceived=1.
- Android ImageDecoder reported hasGainmap=true. Gainmap is 1536x2275,
  ratioMin=[1,1,1], ratioMax approximately [3,3,3], fullHdrRatio approximately 3.
- Gainmap sampled as ALPHA_8: 984/1024 samples differed from the first sample,
  establishing non-uniform image data rather than a metadata-only HDR label.
- IMG_20261010_124718.HEIC: 1180523 bytes, 3072x4550, fullImageReceived=1,
  capture/save ~0.92s. Android ImageDecoder reported hasGainmap=false. This is
  a successful HEIF SDR regression test, NOT a successful HEIF HDR test.
- Camera provider PID 15608 remained alive across both captures.

Independent Android decoder probe source is CameraHdrDecodeProbe.java, retained
with tests. It uses public Bitmap/Gainmap APIs. Run app_process as shell UID,
not root, against a saved image. An older SDR negative-control image repeatedly
caused the process to be killed; that negative-control probe is not counted as
a passing test. The failed HEIF placeholder did decode with hasGainmap=false.

Graph and property are reflected in tree. The property was enabled at runtime;
camera service restart was tested, but this HDR change has not yet had another
full reboot or complete ROM build/flash. Existing fingerprint/audio fixes and
the reference repository were not changed by this work.
