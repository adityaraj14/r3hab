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
            let morning = app.buttons["Knee resting pain 1"]
            XCTAssertTrue(morning.waitForExistence(timeout: 4), app.debugDescription)
            morning.tap()
            snap(app, "05-morning")
            app.navigationBars.buttons["Save"].tap()
        }

        // The session row opens the guided recorder.
        let logSession = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Seated leg extension")
        ).firstMatch
        XCTAssertTrue(logSession.waitForExistence(timeout: 6), app.debugDescription)
        let exercise = app.descendants(matching: .any)["prototype-guided-exercise"]
        for _ in 0..<4 where !exercise.exists {
            if logSession.isHittable { logSession.tap() }
            _ = exercise.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(exercise.exists, app.debugDescription)
        app.buttons["prototype-next"].tap()
        app.buttons["prototype-guided-warmup-skip"].tap()
        let pain = app.descendants(matching: .any)["prototype-guided-pain"]
        for _ in 0..<6 where !pain.exists {
            let same = app.buttons["prototype-guided-same-as-target"]
            if same.waitForExistence(timeout: 2) { same.tap() }
        }
        XCTAssertTrue(pain.waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["prototype-pain-chip-2"].tap()
        app.buttons["prototype-next"].tap()
        app.buttons["prototype-next"].tap()
        app.buttons["prototype-save"].tap()

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
        "The greatest threat to success"
    ]
}
