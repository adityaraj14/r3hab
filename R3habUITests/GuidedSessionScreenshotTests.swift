import XCTest

/// Logs one isometric hold, skips the other two exercises, and finds the row.
final class GuidedSessionScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLogIsometricHoldAppearsInTheLog() throws {
        let app = XCUIApplication()
        app.launch()

        let start = app.buttons["log-session-button"]
        XCTAssertTrue(start.waitForExistence(timeout: 8), app.debugDescription)
        start.tap()

        let title = app.descendants(matching: .any)["guided-exercise-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue(title.label.contains("Isometric leg extension"))

        app.buttons["guided-set-0-load-plus"].tap()
        app.buttons["guided-pain-2"].tap()
        app.buttons["guided-next"].tap()

        let heavy = app.descendants(matching: .any)["guided-exercise-title"]
        XCTAssertTrue(heavy.waitForExistence(timeout: 4))
        XCTAssertTrue(heavy.label.contains("Leg extension heavy"))
        app.buttons["guided-skip"].tap()

        let press = app.descendants(matching: .any)["guided-exercise-title"]
        XCTAssertTrue(press.waitForExistence(timeout: 4))
        XCTAssertTrue(press.label.contains("Leg press"))
        app.buttons["guided-skip"].tap()

        let save = app.buttons["guided-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 4), app.debugDescription)
        save.tap()

        XCTAssertTrue(app.buttons["log-session-button"].waitForExistence(timeout: 6))
        app.tabBars.buttons["Log"].tap()
        let entries = app.descendants(matching: .any).matching(identifier: "session-log-entry")
        XCTAssertTrue(entries.firstMatch.waitForExistence(timeout: 6), app.debugDescription)
        let logged = entries.allElementsBoundByIndex.contains { element in
            element.label.contains("Isometric leg extension") && element.label.contains("Pain 2")
        }
        XCTAssertTrue(logged, app.debugDescription)
    }
}
