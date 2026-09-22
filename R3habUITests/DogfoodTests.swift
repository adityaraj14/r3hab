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

        let skip = app.buttons["Skip for now"]
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

        if app.buttons["Log morning pain"].waitForExistence(timeout: 3) {
            app.buttons["Log morning pain"].tap()
            let morning = app.buttons["Knee resting pain 1"]
            XCTAssertTrue(morning.waitForExistence(timeout: 4), app.debugDescription)
            morning.tap()
            snap(app, "05-morning")
            app.navigationBars.buttons["Save"].tap()
        }

        let logSession = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Log seated extension")
        ).firstMatch
        if logSession.waitForExistence(timeout: 4) {
            logSession.tap()
            let during = app.buttons["During (required) 2"]
            if !during.waitForExistence(timeout: 2) {
                app.swipeUp()
            }
            XCTAssertTrue(during.waitForExistence(timeout: 4), app.debugDescription)
            during.tap()
            app.navigationBars.buttons["Save"].tap()
        }

        XCTAssertTrue(poster.waitForExistence(timeout: 8))
        snap(app, "08-today-after-session")
        XCTAssertTrue(poster.label.contains("1 session"), poster.label)

        app.tabBars.buttons["History"].tap()
        let add = app.buttons["Add a past day"]
        XCTAssertTrue(add.waitForExistence(timeout: 4), app.debugDescription)
        add.tap()
        app.buttons["Add a past workout"].tap()
        app.navigationBars.buttons["Continue"].tap()

        let pastPain = app.buttons["During (required) 2"]
        XCTAssertTrue(pastPain.waitForExistence(timeout: 6), app.debugDescription)
        pastPain.tap()
        app.navigationBars.buttons["Save"].tap()

        app.tabBars.buttons["Today"].tap()
        let resolve = app.buttons["Resolve 24h response"]
        XCTAssertTrue(resolve.waitForExistence(timeout: 8), app.debugDescription)
        resolve.tap()

        let better = app.buttons["response-better"]
        XCTAssertTrue(better.waitForExistence(timeout: 4), app.debugDescription)
        better.tap()
        let close = app.descendants(matching: .any)["close-line"]
        XCTAssertTrue(close.waitForExistence(timeout: 2))
        snap(app, "09-resolve")
        XCTAssertTrue(
            close.label.contains("Stay.") || close.label.contains("Progress."),
            close.label
        )
        app.navigationBars.buttons["Save"].tap()
        if app.buttons["Got it"].waitForExistence(timeout: 2) {
            app.buttons["Got it"].tap()
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
        "The greatest threat to success"
    ]
}
