import XCTest

final class AccessibilityTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeAccessibility() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-seed-scan"]
        app.launch()
        
        try app.performAccessibilityAudit { issue in
            // Skip noisy contrast and element detection issues in simulator
            return issue.auditType == .contrast || issue.auditType == .elementDetection
        }
    }

    @MainActor
    func testScanDetailAccessibility() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-seed-scan"]
        app.launch()
        
        XCTAssertTrue(app.staticTexts["Seeded Invoice"].waitForExistence(timeout: 5))
        app.staticTexts["Seeded Invoice"].tap()
        
        try app.performAccessibilityAudit { issue in
            return issue.auditType == .contrast || issue.auditType == .elementDetection
        }
    }

    @MainActor
    func testPagePreviewAccessibility() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-seed-scan"]
        app.launch()
        
        XCTAssertTrue(app.staticTexts["Seeded Invoice"].waitForExistence(timeout: 5))
        app.staticTexts["Seeded Invoice"].tap()
        
        let openBtn = app.buttons["Open page 1"]
        XCTAssertTrue(openBtn.waitForExistence(timeout: 5))
        openBtn.tap()
        
        try app.performAccessibilityAudit { issue in
            return issue.auditType == .contrast || issue.auditType == .elementDetection
        }
    }
}
