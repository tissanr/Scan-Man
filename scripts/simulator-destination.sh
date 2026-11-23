#!/bin/sh
# Prints an xcodebuild destination for the first available iPhone simulator on the newest
# installed iOS runtime, so builds don't break when Xcode ships new device names/runtimes.
set -eu

udid=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
def version(runtime):
    return [int(part) for part in runtime.rsplit("iOS-", 1)[1].split("-")]
for runtime in sorted((r for r in devices if ".iOS-" in r), key=version, reverse=True):
    for device in devices[runtime]:
        if device["name"].startswith("iPhone"):
            print(device["udid"])
            sys.exit(0)
sys.exit("No available iPhone simulator found")
')

echo "platform=iOS Simulator,id=$udid"
