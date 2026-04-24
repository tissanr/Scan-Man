import XCTest

final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureMarketingScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-seed-scan"]
        app.launch()

        // 1. Home Screen
        takeScreenshot(named: "01_Home")

        // 2. Search flow (Just show the bar for now)
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        list.swipeDown() // Ensure search bar is visible
        
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        takeScreenshot(named: "02_Search_Active")
        app.keyboards.firstMatch.typeText("\r") // dismiss search

        // 3. Scan Detail
        let scanRow = app.staticTexts["ScanTitle"]
        XCTAssertTrue(scanRow.waitForExistence(timeout: 5))
        scanRow.tap()
        takeScreenshot(named: "03_Detail")

        // 4. Page Preview with OCR
        let pageBtn = app.buttons["Open page 1"]
        XCTAssertTrue(pageBtn.waitForExistence(timeout: 5))
        pageBtn.tap()
        XCTAssertTrue(app.otherElements["Page preview"].waitForExistence(timeout: 2))
        takeScreenshot(named: "04_PagePreview_Base")
        
        // Toggle layout overlay if possible (assuming it's on by default in seeded view)
        XCTAssertTrue(app.staticTexts["Detected Layout"].waitForExistence(timeout: 2))
        takeScreenshot(named: "05_PagePreview_With_OCR_Overlay")
    }

    private func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
