#!/usr/bin/env bash
# Runs the unit tests on the newest available iPhone simulator (iOS 17+), unsigned.
set -euo pipefail
cd "$(dirname "$0")/.."
SIM_ID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
def version(runtime):
    try:
        return tuple(int(p) for p in runtime.split("iOS-")[1].split("-"))
    except (IndexError, ValueError):
        return ()
for runtime in sorted((r for r in devices if "iOS-" in r), key=version, reverse=True):
    if version(runtime) < (17,):
        continue
    for device in devices[runtime]:
        if device["name"].startswith("iPhone"):
            print(device["udid"])
            sys.exit(0)
sys.exit("No iOS 17+ iPhone simulator found")
')
echo "Using simulator $SIM_ID"
mkdir -p build
rm -rf build/TestResults.xcresult
xcodebuild test \
  -project RecoveryiOS.xcodeproj \
  -scheme RecoveryiOS \
  -destination "id=$SIM_ID" \
  -resultBundlePath build/TestResults.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  | tee build/xcodebuild-test.log \
  | xcpretty --report junit --output build/junit.xml
