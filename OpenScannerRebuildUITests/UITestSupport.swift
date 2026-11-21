import XCTest

extension XCUIApplication {
    static func launched(_ arguments: String...) -> XCUIApplication {
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
        pageButton.tap()
        XCTAssertTrue(navigationBars["Page 1"].waitForExistence(timeout: 10), file: file, line: line)
    }

    /// Scrolls the main list until `element` can be tapped.
    func scrollTo(_ element: XCUIElement, maxSwipes: Int = 6) {
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            collectionViews.firstMatch.swipeUp()
            swipes += 1
        }
    }
}
