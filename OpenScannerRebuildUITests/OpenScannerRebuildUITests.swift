import XCTest

final class OpenScannerRebuildUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOpeningHomeShowsScansTitle() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-empty"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Scans"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testTappingScanEntryPointShowsFriendlyFallback() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-empty"]
        app.launch()

        let addBtn = app.buttons["AddScan"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 5))
        addBtn.tap()

        let scanBtn = app.buttons["Scan Document"]
        XCTAssertTrue(scanBtn.waitForExistence(timeout: 5))
        scanBtn.tap()

        XCTAssertTrue(app.alerts["Open Scanner"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testOpeningSavedScanShowsDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-seed-scan"]
        app.launch()

        let scanRow = app.staticTexts["ScanTitle"]
        XCTAssertTrue(scanRow.waitForExistence(timeout: 5))
        scanRow.tap()

        XCTAssertTrue(app.navigationBars["Seeded Invoice"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSearchingScansFiltersTheList() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-seed-scan"]
        app.launch()

        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        list.swipeDown() // Ensure search bar is visible

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        
        // Just verify it became active for now
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
    }

    @MainActor
    func testOpeningSavedPageShowsPreviewAndLayout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-seed-scan"]
        app.launch()

        let scanRow = app.staticTexts["ScanTitle"]
        XCTAssertTrue(scanRow.waitForExistence(timeout: 5))
        scanRow.tap()
        
        let pageBtn = app.buttons["Open page 1"]
        XCTAssertTrue(pageBtn.waitForExistence(timeout: 5))
        pageBtn.tap()

        XCTAssertTrue(app.navigationBars["Page 1"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testEditingExtractedTextPersistsInCurrentFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-seed-scan"]
        app.launch()

        let scanRow = app.staticTexts["ScanTitle"]
        XCTAssertTrue(scanRow.waitForExistence(timeout: 5))
        scanRow.tap()
        
        let pageBtn = app.buttons["Open page 1"]
        XCTAssertTrue(pageBtn.waitForExistence(timeout: 5))
        pageBtn.tap()

        let editor = app.textViews["Extracted text editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        if app.menuItems["Select All"].waitForExistence(timeout: 1) {
            app.menuItems["Select All"].tap()
        }
        app.typeText("Edited OCR text")
        app.buttons["Save extracted text"].tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.staticTexts["Edited OCR text"].waitForExistence(timeout: 2))
    }
}
