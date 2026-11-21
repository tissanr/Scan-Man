import XCTest

extension XCUIApplication {
    static func launched(_ arguments: String...) -> XCUIApplication {
        // Another test configuration (e.g. the launch test) may have left the simulator rotated.
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    func openSeededScan(file: StaticString = #filePath, line: UInt = #line) {
        let scanRow = staticTexts["ScanTitle"]
        XCTAssertTrue(scanRow.waitForExistence(timeout: 10), file: file, line: line)
        scanRow.tap()
        XCTAssertTrue(navigationBars["Seeded Invoice"].waitForExistence(timeout: 10), file: file, line: line)
    }

    func openFirstPage(file: StaticString = #filePath, line: UInt = #line) {
        let pageButton = buttons["Open page 1"]
        XCTAssertTrue(pageButton.waitForExistence(timeout: 10), file: file, line: line)
        scrollTo(pageButton)
        pageButton.tap()
        XCTAssertTrue(navigationBars["Page 1"].waitForExistence(timeout: 10), file: file, line: line)
    }

    /// Scrolls the main list until `element` is hittable and its top part is well inside the screen.
    func scrollTo(_ element: XCUIElement, maxSwipes: Int = 6) {
        let screen = windows.firstMatch.frame
        var swipes = 0
        while swipes < maxSwipes && (!element.isHittable || element.frame.minY > screen.maxY - 250) {
            collectionViews.firstMatch.swipeUp(velocity: .slow)
            swipes += 1
        }
    }

    /// Taps near the top of a (possibly tall) text view and waits for it to take focus.
    func focus(_ textView: XCUIElement) {
        scrollTo(textView)
        textView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
    }
}
