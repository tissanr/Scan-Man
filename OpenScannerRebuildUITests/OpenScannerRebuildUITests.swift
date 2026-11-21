import XCTest

final class OpenScannerRebuildUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyLibraryShowsScansTitleAndEmptyState() throws {
        let app = XCUIApplication.launched("--ui-testing-empty")
        XCTAssertTrue(app.navigationBars["Scans"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No Scans Yet"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testScanEntryPointShowsFriendlyFallbackInSimulator() throws {
        let app = XCUIApplication.launched("--ui-testing-empty")

        let addButton = app.buttons["AddScan"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        addButton.tap()

        let scanButton = app.buttons["Scan Document"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 5))
        scanButton.tap()

        XCTAssertTrue(app.alerts["Scan Man"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOpeningSavedScanShowsDetail() throws {
        let app = XCUIApplication.launched("--ui-testing-seed-scan")
        app.openSeededScan()
        XCTAssertTrue(app.buttons["AddPages"].exists)
    }

    @MainActor
    func testSearchingFiltersTheList() throws {
        let app = XCUIApplication.launched("--ui-testing-seed-scan")
        XCTAssertTrue(app.staticTexts["ScanTitle"].waitForExistence(timeout: 10))

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()

        searchField.typeText("invoice")
        XCTAssertTrue(app.staticTexts["ScanTitle"].waitForExistence(timeout: 5))

        searchField.typeText("zzz")
        XCTAssertTrue(app.staticTexts["ScanTitle"].waitForNonExistence(timeout: 5))
    }

    @MainActor
    func testOpeningPageShowsPreviewAndActions() throws {
        let app = XCUIApplication.launched("--ui-testing-seed-scan")
        app.openSeededScan()
        app.openFirstPage()

        let actions = app.buttons["PageActions"]
        XCTAssertTrue(actions.waitForExistence(timeout: 5))
        actions.tap()
        XCTAssertTrue(app.buttons["Rotate Right"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Crop…"].exists)
    }

    @MainActor
    func testEditingExtractedTextUpdatesThePageList() throws {
        let app = XCUIApplication.launched("--ui-testing-seed-scan")
        app.openSeededScan()
        app.openFirstPage()

        let editor = app.textViews["Extracted text editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        app.focus(editor)
        editor.typeText(" Edited OCR text")
        XCTAssertTrue((editor.value as? String ?? "").contains("Edited OCR text"))

        // Dismiss the keyboard so it doesn't cover the Save button.
        let done = app.buttons["DismissKeyboard"]
        if done.waitForExistence(timeout: 3) {
            done.tap()
        }

        let save = app.buttons["Save extracted text"]
        app.scrollTo(save)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        // Once stored, the editor matches the saved text and Save disables again.
        XCTAssertTrue(save.wait(for: \.isEnabled, toEqual: false, timeout: 5))

        // Leave and reopen the page: the edit must have been stored.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.openFirstPage()

        let reopened = app.textViews["Extracted text editor"]
        XCTAssertTrue(reopened.waitForExistence(timeout: 5))
        XCTAssertTrue((reopened.value as? String ?? "").contains("Edited OCR text"))
    }

    @MainActor
    func testSettingsCanBeOpenedAndClosed() throws {
        let app = XCUIApplication.launched("--ui-testing-empty")

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Default Filter"].exists || app.buttons["Default Filter"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Scans"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOnboardingIsShownOnFirstLaunch() throws {
        let app = XCUIApplication.launched("--ui-testing-empty", "--ui-testing-onboarding")

        XCTAssertTrue(app.staticTexts["Welcome to Scan Man"].waitForExistence(timeout: 10))
        app.buttons["GetStarted"].tap()
        XCTAssertTrue(app.staticTexts["Welcome to Scan Man"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Scans"].exists)
    }
}
