# Stock library installation ownership

Attempt 20261015-214924 passed VINTF packaging and Make discovery, then failed
at 22:54:01 with duplicate Ninja symbol output rules. Reading all active Soong
shards found six competing source/prebuilt owners: the three cameraservice
NDK interfaces, Bluetooth audio implementation/session, and libwifi-system-iface.

The stock modules now use canonical source identities with prefer=true rather
than independent `_vendor` aliases sharing the same installed filename. Camera
interfaces and Wi-Fi expose vendor-only prebuilt inputs while retaining source
core/product counterparts; vendor Make names use `.vendor`. The two Bluetooth
vendor-only modules keep their canonical names and their stock V4 dependencies.

Soong cc/image.go previously applied target.vendor.srcs only to source library
compilers, not prebuilt linkers. A small corresponding prebuilt branch now
passes those inputs into the prebuilt selector. TestPrebuiltVendorOnlySrcsPreserveCore
fails against the old implementation and passes with the fix. The full cc Go
suite passed afterward, including an isolated test using the actual camera
prebuilt definition and exported vendor namespace. Source vendor selection,
retained source core selection and the distinct vendor Make suffix were checked.

An early isolated fixture omitted namespace export; that test setup was corrected.
The final issue was missing prebuilt vendor inputs, not an inherent inability
to select a preferred prebuilt from the exported vendor namespace.

Generated AIDL header exports and small source header providers preserve build
interfaces. extract-files.py calls scripts/stock_library_owners.py after fresh
generation so aliases and target scopes do not regress. Do not regenerate the
whole vendor tree merely to apply this fix. The postprocessor is idempotent.

All seven existing device Python tests passed; Python compilation and diff checks
passed. Full regenerated ROM Ninja validation remains pending after restart.
No duplicate-rule checks were relaxed. No blob byte, ELF dependency, live device
file or previously verified runtime configuration was changed.

Unchanged SHA-256 values:

- cameraservice.common-V1-ndk: 4878337a50656708a5c9e0a5368cb75f2264ea68cf6fee4d75e15995d16e8039
- cameraservice.device-V2-ndk: 885cc033cc618f847540ef84181feb29245c83f6b7c397e1de6b2b2e6c3a913b
- cameraservice.service-V2-ndk: 7636cd227ccb0bbdc0c9db5c002e84e4a04888def3af2affea7b51346442d44b
- bluetooth.audio-impl: 229b1b0edea13b79c5d0e9faa7422107dec86609af71e4dd2c34b5daa29e1522
- libbluetooth_audio_session_aidl: afe2cc1c35bcffaf9831c83d57e10ca7fae7fbabf35252c9f8b735ff8f6b516c
- libwifi-system-iface: b459ea89648bb8133fdd967c2cf21a5a65cced6511e1641483b92ab869d622e3
