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

        // 2. Search flow
        let searchField = app.searchFields.firstMatch
        searchField.tap()
        searchField.typeText("Invoice")
        takeScreenshot(named: "02_Search")

        // 3. Scan Detail
        app.staticTexts["Seeded Invoice"].tap()
        takeScreenshot(named: "03_Detail")

        // 4. Page Preview with OCR
        app.buttons["Open page 1"].tap()
        takeScreenshot(named: "04_PagePreview")
    }

    private func takeScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
