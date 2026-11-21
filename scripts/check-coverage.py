#!/usr/bin/env python3
"""Prints per-target line coverage from an .xcresult and fails if the app target is below a threshold.

Usage: check-coverage.py TestResults.xcresult [threshold-percent]
"""
import json
import subprocess
import sys

result_bundle = sys.argv[1]
threshold = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0

report = json.loads(subprocess.check_output(
    ["xcrun", "xccov", "view", "--report", "--json", result_bundle]
))

app_coverage = None
print(f"{'Target':45} {'Lines':>8}")
for target in report.get("targets", []):
    name = target["name"]
    coverage = target["lineCoverage"] * 100
    print(f"{name:45} {coverage:7.1f}%")
    if name == "OpenScannerRebuild.app":
        app_coverage = coverage
        files = sorted(target.get("files", []), key=lambda f: f["lineCoverage"])
        print("\n  Least covered app files:")
        for f in files[:10]:
            print(f"    {f['name']:41} {f['lineCoverage'] * 100:7.1f}%")
        print()

if app_coverage is None:
    sys.exit("App target not found in coverage report")

print(f"App line coverage: {app_coverage:.1f}% (threshold {threshold:.1f}%)")
if app_coverage < threshold:
    sys.exit(f"Coverage {app_coverage:.1f}% is below the {threshold:.1f}% threshold")
