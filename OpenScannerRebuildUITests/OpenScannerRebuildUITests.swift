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

        app.buttons["Scan document"].tap()

        XCTAssertTrue(app.alerts["Open Scanner"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testOpeningSavedScanShowsDetail() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-seed-scan"]
        app.launch()

        app.staticTexts["Seeded Invoice"].tap()

        XCTAssertTrue(app.staticTexts["Pages"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testSearchingScansFiltersTheList() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-seed-scan"]
        app.launch()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("Invoice")

        XCTAssertTrue(app.staticTexts["Seeded Invoice"].waitForExistence(timeout: 2))
    }
}
