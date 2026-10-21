"""Select stock vendor libraries without replacing their core/host counterparts."""
import re
import sys
from pathlib import Path

CAMERA = (
    'android.frameworks.cameraservice.common-V1-ndk',
    'android.frameworks.cameraservice.device-V2-ndk',
    'android.frameworks.cameraservice.service-V2-ndk',
)
STOCK = CAMERA + (
    'android.hardware.bluetooth.audio-impl',
    'libbluetooth_audio_session_aidl',
    'libwifi-system-iface',
)


def configure_stock_library_owners(contents):
    for name in STOCK:
        contents = contents.replace(f'"{name}_vendor"', f'"{name}"')
    for name in STOCK:
        marker = f'    name: "{name}",\n'
        position = contents.index(marker)
        start = contents.rfind('cc_prebuilt_library_shared {', 0, position)
        if start < 0:
            raise ValueError(f'Not a shared prebuilt: {name}')
        end = contents.index('\n}\n', position) + 3
        block = contents[start:end]
        if 'prefer: true' not in block:
            raise ValueError(f'Stock provider must be preferred: {name}')
        if name in CAMERA or name == 'libwifi-system-iface':
            block = block.replace('soc_specific: true', 'vendor_available: true')
            if '        android_arm64: {' in block:
                block = block.replace('        android_arm64: {', '        vendor: {', 1)
            elif '        vendor: {' not in block:
                # The existing Wi-Fi manual prebuilt has top-level lists.
                properties = re.findall(r'(?ms)^    (?:srcs|shared_libs): \[.*?\],\n', block)
                if len(properties) != 2:
                    raise ValueError(f'Unexpected source/dependency layout: {name}')
                for prop in properties:
                    block = block.replace(prop, '', 1)
                nested = ''.join('        ' + line for prop in properties
                                 for line in prop.splitlines(keepends=True))
                block = block.replace(marker, marker + '    target: {\n        vendor: {\n'
                                      + nested + '        },\n    },\n', 1)
            # Dependencies and exported headers are portable across images;
            # only the proprietary implementation input is vendor-only.
            for prop in re.findall(r'(?ms)^            shared_libs: \[.*?\],\n', block):
                block = block.replace(prop, '', 1)
                root_prop = ''.join(line[8:] for line in prop.splitlines(keepends=True))
                block = block.replace(marker, marker + root_prop, 1)
            block = re.sub(r'(?m)^            (?:generated_headers|export_generated_headers|export_shared_lib_headers|header_libs|export_header_lib_headers): \[[^\n]*\],\n', '', block)
            if name in CAMERA and 'generated_headers:' not in block:
                properties = (
                    f'    generated_headers: ["{name}-source"],\n'
                    f'    export_generated_headers: ["{name}-source"],\n'
                )
                imports = {
                    CAMERA[0]: [],
                    CAMERA[1]: [CAMERA[0], 'android.hardware.common.fmq-V1-ndk',
                                'android.hardware.common-V2-ndk'],
                    CAMERA[2]: [CAMERA[0], CAMERA[1]],
                }[name]
                if imports:
                    properties += '    export_shared_lib_headers: [' + ', '.join(
                        f'"{item}"' for item in imports) + '],\n'
                block = block.replace(marker, marker + properties, 1)
            if name == 'libwifi-system-iface' and 'xuanyuan_wifi_system_iface_headers' not in block:
                block = block.replace(marker, marker
                    + '    header_libs: ["xuanyuan_wifi_system_iface_headers"],\n'
                    + '    export_header_lib_headers: ["xuanyuan_wifi_system_iface_headers"],\n', 1)
        elif name == 'libbluetooth_audio_session_aidl' and 'xuanyuan_bluetooth_audio_session_headers' not in block:
            block = block.replace(marker, marker
                + '    header_libs: ["xuanyuan_bluetooth_audio_session_headers"],\n'
                + '    export_header_lib_headers: ["xuanyuan_bluetooth_audio_session_headers"],\n', 1)
        contents = contents[:start] + block + contents[end:]
    return contents


if __name__ == '__main__':
    path = Path(sys.argv[1])
    path.write_text(configure_stock_library_owners(path.read_text()))
