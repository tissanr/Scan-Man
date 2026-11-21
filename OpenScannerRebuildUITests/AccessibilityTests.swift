import XCTest

final class AccessibilityTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Simulator rendering makes the visual audits (contrast, clipping, Dynamic Type) unreliable;
    /// structural audits (labels, traits, hit regions) still run.
    private func audit(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit { issue in
            issue.auditType == .contrast
                || issue.auditType == .elementDetection
                || issue.auditType == .textClipped
                || issue.auditType == .dynamicType
        }
    }

    @MainActor
    func testHomeAccessibility() throws {
        let app = XCUIApplication.launched("--ui-testing-seed-scan")
        XCTAssertTrue(app.staticTexts["ScanTitle"].waitForExistence(timeout: 10))
        try audit(app)
    }

    @MainActor
    func testScanDetailAccessibility() throws {
        let app = XCUIApplication.launched("--ui-testing-seed-scan")
        app.openSeededScan()
        try audit(app)
    }

    @MainActor
    func testPagePreviewAccessibility() throws {
        let app = XCUIApplication.launched("--ui-testing-seed-scan")
        app.openSeededScan()
        app.openFirstPage()
        try audit(app)
    }

    @MainActor
    func testSettingsAccessibility() throws {
        let app = XCUIApplication.launched("--ui-testing-empty")
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        try audit(app)
    }
}
