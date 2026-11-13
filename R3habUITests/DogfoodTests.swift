import XCTest

/// Walks Today’s poster, a seated-extension log, and the 24-hour close.
/// Screenshots land in /tmp/r3hab-dogfood.
final class DogfoodTests: XCTestCase {
    private let shotDir = URL(fileURLWithPath: "/tmp/r3hab-dogfood", isDirectory: true)

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    func testRituals() throws {
        let app = XCUIApplication()
        app.launch()

        let skip = app.buttons["Not now"]
        if skip.waitForExistence(timeout: 8) {
            skip.tap()
        }

        let poster = app.descendants(matching: .any)["today-poster"]
        XCTAssertTrue(poster.waitForExistence(timeout: 10), app.debugDescription)
        snap(app, "04-today")
        let quoteHit = MotivationalQuotesForTest.all.contains { quote in
            poster.label.localizedCaseInsensitiveContains(quote)
        }
        XCTAssertTrue(quoteHit, "Poster should carry today’s line. Label: \(poster.label)")

        if app.buttons["Record morning pain"].waitForExistence(timeout: 3) {
            app.buttons["Record morning pain"].tap()
            let morning = app.descendants(matching: .any)["morning-pain-ruler"]
            XCTAssertTrue(morning.waitForExistence(timeout: 4), app.debugDescription)
            XCTAssertTrue((morning.value as? String ?? "").hasPrefix("0 of 10"), "No yesterday value: the ruler opens at 0")
            snap(app, "05-morning")
            app.navigationBars.buttons["Save"].tap()
        }

        // Exercise rows live on Today's session, not on the home list.
        let sessionLink = app.descendants(matching: .any)["today-session-link"]
        XCTAssertTrue(sessionLink.waitForExistence(timeout: 6), app.debugDescription)
        XCTAssertFalse(
            app.buttons.matching(identifier: "log-plan-exercise").firstMatch.exists,
            "Exercise rows stay off Today"
        )
        sessionLink.tap()
        XCTAssertTrue(app.navigationBars["Today's session"].waitForExistence(timeout: 6), app.debugDescription)
        let logSession = app.buttons.matching(identifier: "log-plan-exercise").firstMatch
        XCTAssertTrue(logSession.waitForExistence(timeout: 6), app.debugDescription)
        logSession.tap()
        XCTAssertTrue(app.navigationBars["Record session"].waitForExistence(timeout: 6), app.debugDescription)
        let pain = app.buttons["Pain during the session 2"]
        XCTAssertTrue(pain.waitForExistence(timeout: 4), app.debugDescription)
        pain.tap()
        app.buttons["Save"].tap()

        let backToToday = app.navigationBars["Today's session"].buttons["Today"]
        if backToToday.waitForExistence(timeout: 4) {
            backToToday.tap()
        }
        XCTAssertTrue(poster.waitForExistence(timeout: 8))
        snap(app, "08-today-after-session")
        XCTAssertTrue(poster.label.contains("1 session"), poster.label)

        app.tabBars.buttons["History"].tap()
        let add = app.buttons["Add a past day"]
        XCTAssertTrue(add.waitForExistence(timeout: 4), app.debugDescription)
        add.tap()
        app.buttons["Add a past session"].tap()
        app.navigationBars.buttons["Continue"].tap()

        let pastPain = app.buttons["Pain during the session 2"]
        XCTAssertTrue(pastPain.waitForExistence(timeout: 6), app.debugDescription)
        pastPain.tap()
        app.buttons["Save"].tap()

        let resolve = app.buttons["Record the 24-hour response"]
        // The tab tap right after a sheet closes can be lost. Tap again.
        for _ in 0..<3 where !resolve.exists {
            app.tabBars.buttons["Today"].tap()
            _ = resolve.waitForExistence(timeout: 4)
        }
        XCTAssertTrue(resolve.waitForExistence(timeout: 4), app.debugDescription)
        resolve.tap()

        let better = app.buttons["response-better"]
        XCTAssertTrue(better.waitForExistence(timeout: 4), app.debugDescription)
        better.tap()
        let close = app.descendants(matching: .any)["close-line"]
        XCTAssertTrue(close.waitForExistence(timeout: 2))
        snap(app, "09-resolve")
        XCTAssertTrue(
            close.label.contains("same load") || close.label.contains("more load"),
            close.label
        )
        app.navigationBars.buttons["Save"].tap()
        if app.buttons["OK"].waitForExistence(timeout: 2) {
            app.buttons["OK"].tap()
        }

        app.tabBars.buttons["Progress"].tap()
        let readout = app.descendants(matching: .any)["progress-readout"]
        XCTAssertTrue(readout.waitForExistence(timeout: 6), app.debugDescription)
        snap(app, "10-progress")
        XCTAssertFalse(readout.label.isEmpty)
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = shotDir.appendingPathComponent("\(name).png")
        try? app.screenshot().pngRepresentation.write(to: url)
    }
}

/// Mirrors MotivationalQuotes so the UI test can recognize the line without
/// linking the app target.
private enum MotivationalQuotesForTest {
    static let all = [
        "Just keep swimming.",
        "Get up.",
        "Fall down seven times, stand up eight.",
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
}
