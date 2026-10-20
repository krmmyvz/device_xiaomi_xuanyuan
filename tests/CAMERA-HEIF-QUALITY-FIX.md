# SDR JPEG/HEIF and image quality, 2026-10-10

Later JPEG UltraHDR enablement: see CAMERA-HDR-FIX.md. HEIF remains SDR.

The later format fix supersedes the initial JPEG-only graph. UltraHDR gainmaps
remain intentionally disabled (persist.vendor.camera.ultrahdr.enable=0), but
ordinary HEIF encoding is restored. Stock303 executable/shared-library code
was not modified; the reference repository was not used as a copy source.

## JPEG quality measurement

The settings page showed image quality "super" (Japanese: 超高). A controlled
rear-camera comparison re-applied settings through the actual preference UI:

| Setting | Capture metadata | Saved JPEG |
| --- | --- | --- |
| High | jpegQuality=96 | IMG_20261010_120406.jpg, 2312116 bytes |
| Super | jpegQuality=100 | IMG_20261010_120526.jpg, 4986010 bytes |

Super's two JPEG quantization tables each contained 64 coefficients of 1.
High's table maxima were 10 and 8, respectively. Thus the saved Super file
really uses different compression, not merely a different UI label. The
setting was re-applied, not fixed by modifying the Camera APK. A stale prior
session is a possibility, not an established root cause of the user's initial
observation. Do not claim an APK preference-cache defect has been fixed.
Front-camera capture used its default quality 96; Super=100 was validated for
the rear camera only. Do not infer that all camera profiles share the setting.

## Format graph correction

configs/camera/satsnapshot-sdr.json keeps the image-processing/MFNR and primary
JPEG/HEIF codecs while excluding gainmap/JPEG-R and auxiliary sharp HEIF paths.
The primary HEIF writer requires both encoded-image input 0 and metadata/JPEG
input 1. The first candidate omitted input 1 and aborted in
yuv2HeicPlugin::processRequest at line 125. Bypassing the unused JPEG-R
aggregator must preserve the link HeicInstance0:1 -> yuv2HeicInstance:1.
The validated graph has 36 nodes and 46 links, no dangling references, and
retains the original sink/conditional-format handling. RAW bytes are not
relabeled. New graph replaces the device copy rule; stock original and the
initial JPEG-only fallback config remain available for rollback.

scripts/camera-jpeg-graph.mjs --generate-sdr regenerates this graph from the
stock303 satsnapshot JSON. tests/camera-sdr-format-test.mjs initially failed
against JPEG-only and against the first missing-metadata candidate; the final
graph passes. These checks do not replace on-device codec testing.

## Runtime evidence

| Capture | Format / size | Result |
| --- | --- | --- |
| IMG_20261010_121004.jpg | JPEG, 4347321 bytes | fullImageReceived=1, preview=false; JPEG regression passed |
| IMG_20261010_121315.HEIC | HEIF, 1197558 bytes, 3072x4550 | Capture 12:13:15.978, save 12:13:16.916 (~0.94s) |
| IMG_20261010_121400.HEIC | HEIF, 1247976 bytes | fullImageReceived=1, preview=false; second rear success |
| IMG_20261010_121615.HEIC | HEIF, 2023558 bytes, 4896x6528 | Front device 1 capture |

HEICWRITER reported successful muxing. The first rear and front files were
fully decoded into RGB pixels by an independent host HEIF decoder, rather than
only checking filenames or headers. Decoder dimensions are recorded above.
The host-only pillow-heif test dependency is confined to camera-heif-codec in
the Windows task workspace; it is not a ROM dependency or system install.

Live and tree graph SHA-256:
17a26d861fc78c96c8bc7a7ff6e59554610d0c323b8e69917769e4c0317b621d.
Camera service was restarted for the graph change; this later HEIF change has
not yet been tested across another full reboot or a complete ROM build/flash.
Earlier private-libui/JPEG corrections were already validated across reboot.
Telephoto, video, and UltraHDR remain outside this verification.
