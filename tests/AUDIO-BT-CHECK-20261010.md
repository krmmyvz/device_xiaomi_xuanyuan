# Bluetooth silence and post-disconnect volume investigation

User chronology: initial Bluetooth connection was silent on both headset and
handset; after disconnection handset index 0 muted, but every positive index
was reportedly full loudness. Do not describe these as simultaneous events.

Read-only checks and all-zero PCM probes (no system volume increase):

- Music volume curves exist. Speaker index 1 = -58.74 dB, index 2 = -50.97 dB,
  index 7 = -27.608572 dB; Bluetooth index 1 = -62.216667 dB.
- Initial cached AudioFlinger/strategy destination was A2DP, while policy and
  primary HAL patch 13 still targeted speaker port 25/config 99. A silent probe
  reported A2DP although PAL opened PAL_DEVICE_OUT_SPEAKER. This describes the
  observed current state, not proof of the user's initial connection history.
- Explicit preferred-speaker then preferred-A2DP all-zero PCM probes updated
  HAL patch 13 to Bluetooth port 100/config 121. AudioTrack accepted both
  preferred destinations and advanced its playback head; neither proves audio
  reached hardware.
- A2DP control handshake succeeded. Negotiated LDAC: 96 kHz, 32-bit, stereo.
  PAL/AGM then failed to open the playback DSP graph repeatedly with -131:
  `gsl_graph_open_sgids_and_connections: Graph open failed:1`,
  `session_connect_aif: session_id:126, audio interface id:53`,
  `pal_stream_start failed, ret:-131`, and ignored writes.
- Speaker all-zero PCM with track gain 1 reached effect volume listeners as
  left/right 0.041646, consistent with stored speaker index 7, not unity gain.
  Dolby logged mVolume=1073741824 alongside it; that field's meaning and update
  timing have not been established. Do not call it proof of gain corruption.
- Stored music indices stayed speaker=7 and A2DP=1. Probes never changed them.

Windows task workspace evidence: audio-silent-bt-check.log,
audio-silent-speaker-gain-check.log, audio-hal-primary-current.txt,
audio-hal-after-preferred-bt.txt, audio-policy-current-check.txt.

Next discriminating check: disable the headset's HD audio/LDAC temporarily and
repeat all-zero PCM on negotiated SBC/AAC. If the same graph fails, investigate
common DSP/offload graph/configuration inputs; otherwise narrow to LDAC path.
Post-disconnect positive-index loudness still requires a separate controlled
gain-path check. No source fix, service restart, reboot, or flashing performed.

## HD disabled follow-up

User reported no improvement. Bluetooth dump confirms SBC, 44.1 kHz, 16-bit,
stereo (not LDAC). A fresh preferred-speaker -> preferred-A2DP zero-PCM sequence
reproduced `pal_stream_start failed, ret:-131` with SBC as well. The first probe
without that explicit transition still used a speaker HAL patch despite reporting
A2DP; do not treat that first probe's successful PAL start as Bluetooth success.

SBC control handshake succeeds, but graph custom configuration fails. Immediately
before failure ACDB reports `Error[19]: No calibration found`, followed by
`session_apply_aif_device_params: Error:-131 setting device cached params:47`.
Graph alias: PCM_Deep_Buffer / BT_Rx / Audio_MIPLAY / A2DP / GENERIC.
This narrows the investigation to common offload graph/configuration inputs,
not a LDAC-only failure. It does not prove which input causes the failure.

Stock303 comparison: device files match the current vendor tree, but these tree
files do NOT match the local stock303 extraction:

- vendor/lib64/libgsl.so: current SHA256
  331c6f543391fa9359fe93901cb4e27e7bfc7e694fd2a1e8e67b0356ba1cda33;
  stock303 af714541ff1cf42fe245a1d7daf47dadf13c1b541c2655a75a3926d0e007d8cd.
  Build IDs differ: current 53c9ae46d9a47954955929ce992277b8 versus stock303
  017f045b83e1a2521b38a1d9e3b95a60. DT_NEEDED lists are equal.
- vendor/etc/acdbdata/IDP_UPD/IDP_UPD_acdb_cal.acdb: current
  51f422beeac62d840aa48a5c676d0f9ba74723eb2f9cb5579bb7dfa219a626d0;
  stock303 9e664a17a24b00a5e574ab123931e960847ed7886258a0875816423ba7771e70.
- odm/etc/acdbdata/Mi/Mi_acdb_cal.acdb: current
  411ce804e5e24c7823d9092705d649fecce49da6037854d86229085e1a38802b;
  stock303 2a56fd8a848150b66c7b0877588aa66dd132397a6c1eee6846cede446be970b4.
- Both corresponding workspaceFileXml.qwsp files differ from stock303 too.

libar-pal.so, libagm.so, and libaudiocorehal.qti.so match stock303 exactly on the
device. No extraction fixup for libgsl/calibration files was found in the current
device extraction script. Their original provenance/intent remains unestablished;
no replacement was made. Additional evidence: audio-silent-sbc-forced-route.log.

## Authorized stock303 live trial — unsuccessful, reverted

User authorized trying the stock303 candidate set. Before changing anything,
all five device files were pulled and their hashes verified against the device.
Backup directory in the Windows task workspace:
`audio303-live-trial-20261010-170156` (0.original through 4.original in the order
listed in audio303-live-trial.ps1).

Stopped audioserver and vendor.audio-hal-aidl, installed only the five stock303
files, restored file labels, verified all five SHA256 hashes, and started both
services. A new HAL PID 8693 was observed. No reboot, flash, camera property
change, volume increase, or vendor-tree replacement was performed.

The preferred-speaker -> preferred-A2DP all-zero PCM test still failed with SBC:
graph_open returned 0, then DSP graph configuration command opcode 0x1001006
returned failure:1, followed by `session_apply_aif_device_params ... -131 ... 47`
and `pal_stream_start failed, ret:-131`. No calibration warnings also remained.
Consequently, hash mismatch alone is not a sufficient explanation or fix, and
the warnings are not proven to be the causal failure.

Restored all five original files, verified each against its backup, and restarted
both audio services; both report running. The unsuccessful candidate is NOT
integrated into the ROM tree. Runtime evidence: audio303-trial-runtime.log.
Next investigation should identify the exact cached Bluetooth/DSP parameter
payload rejected by graph configuration, rather than stacking more blob changes.

## Further investigation and correction

Important correction: `/vendor/lib64/libgsl.so` is the GRAPHICS library (exports
KGSL functions), not the audio GSL library that emits `gsl_graph.c` logs. The
previous live trial restored it successfully; do not promote that candidate or
describe its hash mismatch as an audio-GSL mismatch. Actual audio libraries
`libar-gsl.so` and `libar-acdb.so` match stock303 exactly.

Active ODM resourcemanager_sun_mtp.xml, mixer_paths_sun_mtp.xml, and
audio_module_config_primary.xml all match stock303. Generic vendor XML differs,
but that alone does not establish that PAL selected it. A wrong-speaker-backend
inference from vendor XML is not justified by the observed TDM speaker route.

ADSP-containing firmware: first 172568576 bytes of active modem_b exactly match
stock303 NON-HLOS.bin, SHA256
ad86ea5818b7906ea63a7a88910a6d006257d35b9d5d0a5ba67ea7edc4f696c3.
The raw DSP partition hash differs, but it is an RW ext4 filesystem; compared
contents sbc_enc_module.so.1, ldac_enc_module.so.1, aac_enc_etsi_module.so.1, and
msppv4_module.so.1 all match files extracted read-only from stock303 dspso.bin.
No firmware flashing is justified by these checks.

Standalone plugin comparison: current lib_bt_bundle.so and stock303 code differ
in .text, but both pack the same SBC diagnostic fixture into byte-identical
parameter blocks. lib_bt_ble.so and bluetooth.audio-impl.so have identical .text
despite whole-file hash differences. No further plugin replacement performed.
Fixture results: bt-bundle-current-payload.txt / bt-bundle-stock303-payload.txt in
the Windows task workspace. This single fixture does not cover all codecs.

A 30-second strace capture of HAL PID9410 read/write on GPR fd6, while probing
all-zero PCM, records the actual failing transaction. A 200-byte in-band SET_CFG
packet (opcode 0x01001006) contains five settings:
placeholder reset 0x08001173, encoder module 0x0800100b, bitrate 0x08001052,
encoder configuration 0x08001009, PCM converter 0x08001008. DSP BASIC_RSP_RESULT
opcode 0x02001005 returns status 1 for SET_CFG. The response does not identify
which of the five settings failed. Do not claim a specific rejected parameter
from this capture alone. No raw DSP command was injected and no packet changed.
Tracing detached from all threads at timeout; both audio services remain running.
Evidence: audio-gpr-bt-check-20261010.trace. Root cause and audible repair remain
unverified. Next choice: finer per-setting diagnostic instrumentation, or a
reversible software-A2DP bypass experiment to isolate hardware offload further.
