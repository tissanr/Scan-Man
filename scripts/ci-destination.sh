#!/usr/bin/env bash
# Prints an xcodebuild -destination value for the newest available iPhone simulator.
set -euo pipefail
xcrun simctl list devices available -j | python3 -c '
import json, re, sys
data = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in data.items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    for d in devices:
        if d["name"].startswith("iPhone") and "Pro" not in d["name"] and "Plus" not in d["name"]:
            key = (version, d["name"])
            if best is None or key > best[0]:
                best = (key, d["udid"])
if best is None:
    sys.exit("No available iPhone simulator found")
print(f"platform=iOS Simulator,id={best[1]}")
'
