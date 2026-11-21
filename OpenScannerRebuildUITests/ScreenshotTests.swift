import XCTest

/// Captures App Store screenshots as test attachments (see `make screenshot`).
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureMarketingScreenshots() throws {
        let app = XCUIApplication.launched("--ui-testing-seed-scan")
        XCTAssertTrue(app.staticTexts["ScanTitle"].waitForExistence(timeout: 10))
        takeScreenshot(named: "01_Home")

        app.openSeededScan()
        takeScreenshot(named: "02_Detail")

        app.openFirstPage()
        takeScreenshot(named: "03_Page_With_OCR_Overlay")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        takeScreenshot(named: "04_Settings")
    }

    private func takeScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
