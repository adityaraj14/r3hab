import XCTest

/// Home is a quote and one log button. The other tabs are Log and Guide.
/// Nothing on launch asks for a check-in or a notification.
final class DogfoodTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHomeIsQuoteAndLogButton() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertFalse(app.buttons["Not now"].exists)
        XCTAssertFalse(app.buttons["Record morning pain"].exists)
        XCTAssertFalse(app.staticTexts["You haven't logged"].exists)

        let quote = app.descendants(matching: .any)["home-quote"]
        XCTAssertTrue(quote.waitForExistence(timeout: 8), app.debugDescription)
        let known = [
            "Just keep swimming.",
            "Get up.",
            "Fall down seven times",
            "I can do this all day.",
            "Why do we fall?",
            "Do or do not.",
            "Don't stop believing.",
            "Believe.",
            "Hakuna matata.",
            "The night is darkest",
            "The greatest threat to success",
            "A moving man will one day meet his luck."
        ]
        XCTAssertTrue(known.contains { quote.label.localizedCaseInsensitiveContains($0) }, quote.label)

        XCTAssertTrue(app.buttons["log-session-button"].exists)
        XCTAssertTrue(app.tabBars.buttons["Home"].exists)
        XCTAssertTrue(app.tabBars.buttons["Log"].exists)
        XCTAssertTrue(app.tabBars.buttons["Guide"].exists)
        XCTAssertFalse(app.tabBars.buttons["Today"].exists)
        XCTAssertFalse(app.tabBars.buttons["History"].exists)
        XCTAssertFalse(app.tabBars.buttons["Progress"].exists)
        XCTAssertFalse(app.tabBars.buttons["Settings"].exists)
    }
}
