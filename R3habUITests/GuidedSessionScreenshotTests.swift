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

        // Prior history can prefill several sets. Leave one so this test stays stable.
        while app.buttons["guided-set-1-remove"].exists {
            app.buttons["guided-set-1-remove"].tap()
        }

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

/// Logs one leg press set three days back, then finds it under that day.
final class BackdatedSessionShots: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBackdatedSessionAppearsUnderItsDay() throws {
        let app = XCUIApplication()
        app.launch()

        let start = app.buttons["log-session-button"]
        XCTAssertTrue(start.waitForExistence(timeout: 8), app.debugDescription)
        start.tap()

        let title = app.descendants(matching: .any)["guided-exercise-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["guided-skip"].tap()
        XCTAssertTrue(title.waitForExistence(timeout: 4))
        app.buttons["guided-skip"].tap()

        XCTAssertTrue(title.waitForExistence(timeout: 4))
        XCTAssertTrue(title.label.contains("Leg press"))
        while app.buttons["guided-set-1-remove"].exists {
            app.buttons["guided-set-1-remove"].tap()
        }
        if !app.buttons["guided-set-0-remove"].exists {
            app.buttons["guided-add-set"].tap()
        }
        app.buttons["guided-set-0-load-plus"].tap()
        app.buttons["guided-pain-1"].tap()
        app.buttons["guided-next"].tap()

        let picker = app.datePickers["guided-date"]
        XCTAssertTrue(picker.waitForExistence(timeout: 4), app.debugDescription)
        shot(app, "01-review-date-today")

        let target = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"
        let dayLabel = formatter.string(from: target)

        picker.buttons.firstMatch.exists ? picker.buttons.firstMatch.tap() : picker.tap()
        let dayButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", dayLabel)).firstMatch
        XCTAssertTrue(dayButton.waitForExistence(timeout: 4), app.debugDescription)
        shot(app, "02-date-picker-open")
        dayButton.tap()
        shot(app, "03-date-picked")

        // Close the calendar pop-up.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        sleep(1)
        shot(app, "04-review-date-backdated")

        app.buttons["guided-save"].tap()
        XCTAssertTrue(app.buttons["log-session-button"].waitForExistence(timeout: 6))
        app.tabBars.buttons["Log"].tap()
        let entries = app.descendants(matching: .any).matching(identifier: "session-log-entry")
        XCTAssertTrue(entries.firstMatch.waitForExistence(timeout: 6), app.debugDescription)
        sleep(1)
        shot(app, "05-log-list")
        print("BACKDATED_TARGET=\(dayLabel)")
        print(app.debugDescription)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let image = app.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] ?? "/private/tmp/r3hab-date-picker-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? image.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }
}
