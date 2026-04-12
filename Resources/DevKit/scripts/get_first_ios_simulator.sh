#!/bin/zsh

set -euo pipefail

# Discover the first iOS Simulator destination whose runtime is actually
# installed and available for the currently selected Xcode.  The old script
# only checked device.isAvailable which can be true even when the runtime
# has not been downloaded yet.

find_simulator() {
    xcrun simctl list --json | python3 -c "
import sys, json

data = json.load(sys.stdin)

# collect runtime identifiers that are both iOS and genuinely available
available_ios_runtimes = {
    rt['identifier']
    for rt in data.get('runtimes', [])
    if rt.get('isAvailable', False) and 'iOS' in rt.get('name', '')
}

if not available_ios_runtimes:
    sys.exit(1)

# pick the first available iPhone whose runtime is installed
for runtime_id, devices in data.get('devices', {}).items():
    if runtime_id not in available_ios_runtimes:
        continue
    for device in devices:
        if device.get('isAvailable', False) and 'iPhone' in device.get('name', ''):
            print(device['udid'])
            sys.exit(0)

sys.exit(1)
"
}

SIMULATOR=$(find_simulator) && {
    echo "[+] using simulator: $SIMULATOR" >&2
    echo "platform=iOS Simulator,id=$SIMULATOR"
    exit 0
}

# no usable simulator found – try installing the iOS platform runtime
echo "[*] no iOS simulator with available runtime, installing iOS platform..." >&2
xcodebuild -downloadPlatform iOS

SIMULATOR=$(find_simulator) || {
    echo "[-] still no available iPhone simulator after platform install" >&2
    exit 1
}

echo "[+] using simulator: $SIMULATOR" >&2
echo "platform=iOS Simulator,id=$SIMULATOR"
