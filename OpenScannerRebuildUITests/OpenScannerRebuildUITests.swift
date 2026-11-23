import XCTest

final class OpenScannerRebuildUITests: XCTestCase {
    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
        // The launch tests run once per UI configuration and can leave the simulator rotated.
        XCUIDevice.shared.orientation = .portrait
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

        XCTAssertTrue(app.alerts["Scan Man"].waitForExistence(timeout: 5))
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
        searchField.typeText("invoice")
        XCTAssertTrue(app.staticTexts["Seeded Invoice"].waitForExistence(timeout: 2))

        searchField.typeText(" nothing matches")
        XCTAssertTrue(app.staticTexts["No Results"].waitForExistence(timeout: 2))
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
        // The editor sits below the preview and layout sections.
        for _ in 0..<4 where !editor.isHittable {
            app.swipeUp()
        }
        editor.tap()
        editor.typeKey("a", modifierFlags: .command)
        editor.typeText("Edited OCR text")
        app.buttons["Save extracted text"].tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.staticTexts["Edited OCR text"].waitForExistence(timeout: 2))
    }
}
