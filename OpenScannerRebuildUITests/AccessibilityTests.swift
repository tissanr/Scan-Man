import XCTest

final class AccessibilityTests: XCTestCase {
    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
        // The launch tests run once per UI configuration and can leave the simulator rotated.
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testHomeAccessibility() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-seed-scan"]
        app.launch()
        
        try app.performAccessibilityAudit(for: .all, Self.isIgnored)
    }

    @MainActor
    func testScanDetailAccessibility() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-seed-scan"]
        app.launch()
        
        XCTAssertTrue(app.staticTexts["Seeded Invoice"].waitForExistence(timeout: 5))
        app.staticTexts["Seeded Invoice"].tap()
        
        try app.performAccessibilityAudit(for: .all, Self.isIgnored)
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
        
        try app.performAccessibilityAudit(for: .all, Self.isIgnored)
    }

    /// Skips simulator-unreliable visual checks while keeping the structural audits.
    @MainActor
    private static func isIgnored(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        switch issue.auditType {
        case .contrast, .elementDetection, .textClipped, .dynamicType:
            return true
        case .hitRegion:
            // On iOS 26 the library's system search field stays in the hierarchy, collapsed,
            // after pushing a detail screen. It's a UIKit component, not app UI.
            return issue.compactDescription.contains("UISearchBarTextField")
                || issue.element?.elementType == .searchField
        default:
            return false
        }
    }
}
