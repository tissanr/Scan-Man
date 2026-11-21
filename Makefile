.PHONY: build test clean lint doc screenshot seed-data help

PROJECT = OpenScannerRebuild.xcodeproj
SCHEME = OpenScannerRebuild
SIMULATOR = $(shell scripts/ci-destination.sh)

help:
	@echo "Available commands:"
	@echo "  make build         - Build the project"
	@echo "  make test          - Run unit and UI tests"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make doc           - Generate DocC documentation"
	@echo "  make screenshot    - Run UI tests and capture screenshots"
	@echo "  make seed-data     - Launch simulator with seeded data"

build:
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination '$(SIMULATOR)' CODE_SIGNING_ALLOWED=NO

test:
	rm -rf build/TestResults.xcresult
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(SIMULATOR)' CODE_SIGNING_ALLOWED=NO -enableCodeCoverage YES -parallel-testing-enabled NO -resultBundlePath build/TestResults.xcresult
	python3 scripts/check-coverage.py build/TestResults.xcresult

clean:
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME)

doc:
	xcodebuild docbuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(SIMULATOR)'

screenshot:
	@echo "Running UI tests to capture screenshots..."
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(SIMULATOR)' -only-testing:OpenScannerRebuildUITests/ScreenshotTests CODE_SIGNING_ALLOWED=NO

seed-data:
	xcrun simctl launch booted me.tissanr.OpenScannerRebuild --ui-testing-seed-scan
