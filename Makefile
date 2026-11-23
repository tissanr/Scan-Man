.PHONY: build test unit-test ui-test clean doc screenshot seed-data help

PROJECT = OpenScannerRebuild.xcodeproj
SCHEME = OpenScannerRebuild
BUNDLE_ID = me.tissanr.OpenScannerRebuild
# Override with e.g. `make test DESTINATION='platform=iOS Simulator,name=iPhone 17'`.
DESTINATION ?= $(shell scripts/simulator-destination.sh)
XCODEBUILD = xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' CODE_SIGNING_ALLOWED=NO

help:
	@echo "Available commands:"
	@echo "  make build         - Build the project"
	@echo "  make test          - Run unit and UI tests with code coverage"
	@echo "  make unit-test     - Run unit tests only (fast)"
	@echo "  make ui-test       - Run UI tests only"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make doc           - Generate DocC documentation"
	@echo "  make screenshot    - Run the screenshot UI test"
	@echo "  make seed-data     - Launch the booted simulator app with seeded data"

build:
	$(XCODEBUILD) build

test:
	$(XCODEBUILD) test -enableCodeCoverage YES -parallel-testing-enabled NO

unit-test:
	$(XCODEBUILD) test -only-testing:OpenScannerRebuildTests

ui-test:
	$(XCODEBUILD) test -only-testing:OpenScannerRebuildUITests -parallel-testing-enabled NO

clean:
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME)

doc:
	xcodebuild docbuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)'

screenshot:
	$(XCODEBUILD) test -only-testing:OpenScannerRebuildUITests/ScreenshotTests

seed-data:
	xcrun simctl launch booted $(BUNDLE_ID) --ui-testing-seed-scan
