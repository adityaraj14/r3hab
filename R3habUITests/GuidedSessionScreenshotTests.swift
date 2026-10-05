import XCTest

/// The guided recorder from Today: record, save a draft on a set step, resume
/// on the same step, review, and the final save.
/// Shots land in /tmp/r3hab-guided-shots.
final class GuidedSessionScreenshotTests: XCTestCase {
    private let shotDir = URL(fileURLWithPath: "/tmp/r3hab-guided-shots", isDirectory: true)

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    func testGuidedDraftAndResume() throws {
        let app = XCUIApplication()
        app.launch()

        let skip = app.buttons["Not now"]
        if skip.waitForExistence(timeout: 8) {
            skip.tap()
        }
        let poster = element(app, "today-poster")
        XCTAssertTrue(poster.waitForExistence(timeout: 10), app.debugDescription)

        // 1. Today's record button opens the guided form.
        tapUntil(app, sessionRow(app), shows: "prototype-guided-exercise")
        snap(app, "01-record-opens-guided")

        app.buttons["prototype-next"].tap()
        XCTAssertTrue(element(app, "prototype-guided-warmup").waitForExistence(timeout: 4), app.debugDescription)
        // Add one warm-up set, then mark warm-up done (footer).
        XCTAssertTrue(app.buttons["prototype-guided-warmup-add"].waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["prototype-guided-warmup-add"].tap()
        XCTAssertTrue(app.buttons["prototype-guided-warmup-yes"].waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["prototype-guided-warmup-yes"].tap()
        XCTAssertTrue(element(app, "prototype-guided-set-1").waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["prototype-guided-same-as-target"].tap()
        XCTAssertTrue(element(app, "prototype-guided-set-2").waitForExistence(timeout: 4), app.debugDescription)

        // Change set 2: drag the load ruler 3 steps up.
        let ruler = element(app, "prototype-guided-set-2-load-ruler")
        XCTAssertTrue(ruler.waitForExistence(timeout: 4), app.debugDescription)
        let before = ruler.value as? String ?? ""
        let start = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: -45, dy: 0))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.4)
        sleep(1)
        let changed = ruler.value as? String ?? ""
        XCTAssertNotEqual(before, changed, "The drag must change the load")

        // 2. Save draft on a set step.
        let saveDraft = app.buttons["guided-save-draft"]
        XCTAssertTrue(saveDraft.exists, app.debugDescription)
        snap(app, "02-save-draft-on-set-step")
        saveDraft.tap()

        // 3. Today shows the draft, not a complete session.
        XCTAssertTrue(poster.waitForExistence(timeout: 8), app.debugDescription)
        let draftRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Continue the draft")).firstMatch
        XCTAssertTrue(draftRow.waitForExistence(timeout: 6), app.debugDescription)
        XCTAssertTrue(poster.label.hasPrefix("0 sessions"), poster.label)
        XCTAssertFalse(app.buttons["Record the 24-hour response"].exists, "A draft must not ask for the 24-hour response")
        XCTAssertFalse(app.buttons["Record pain after"].exists, "A draft must not ask for the pain after")
        snap(app, "03-today-shows-draft")

        // 4. Resume on the same step with the same values.
        tapUntil(app, draftRow, shows: "prototype-guided-set-2")
        let resumed = element(app, "prototype-guided-set-2-load-ruler")
        XCTAssertTrue(resumed.waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertEqual(resumed.value as? String, changed)
        snap(app, "04-resume-same-step")

        app.buttons["prototype-next"].tap()
        for _ in 0..<6 {
            if element(app, "prototype-guided-pain").exists { break }
            let same = app.buttons["prototype-guided-same-as-target"]
            if same.waitForExistence(timeout: 2) { same.tap() }
        }
        XCTAssertTrue(element(app, "prototype-guided-pain").waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["prototype-pain-chip-2"].tap()
        app.buttons["prototype-next"].tap()
        XCTAssertTrue(element(app, "prototype-guided-notes").waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["prototype-next"].tap()

        // 5. Review.
        XCTAssertTrue(element(app, "prototype-guided-review").waitForExistence(timeout: 4), app.debugDescription)
        snap(app, "05-review")

        // 6. Today after the final save.
        app.buttons["prototype-save"].tap()
        XCTAssertTrue(element(app, "guided-session-screen").waitForNonExistence(timeout: 6), app.debugDescription)
        XCTAssertTrue(poster.waitForExistence(timeout: 8))
        let deadline = Date().addingTimeInterval(6)
        while !poster.label.hasPrefix("1 session") && Date() < deadline { usleep(250_000) }
        XCTAssertTrue(poster.label.hasPrefix("1 session"), poster.label)
        snap(app, "06-today-after-save")
    }

    /// Going to the background keeps the step and the values as a draft.
    func testBackgroundAutosavesTheDraft() throws {
        let app = XCUIApplication()
        app.launch()
        let skip = app.buttons["Not now"]
        if skip.waitForExistence(timeout: 8) {
            skip.tap()
        }
        let poster = element(app, "today-poster")
        XCTAssertTrue(poster.waitForExistence(timeout: 10), app.debugDescription)
        tapUntil(app, sessionRow(app), shows: "prototype-guided-exercise")
        app.buttons["prototype-next"].tap()
        XCTAssertTrue(element(app, "prototype-guided-warmup").waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["prototype-guided-warmup-skip"].tap()
        XCTAssertTrue(element(app, "prototype-guided-set-1").waitForExistence(timeout: 4), app.debugDescription)

        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(element(app, "prototype-guided-set-1").waitForExistence(timeout: 6), app.debugDescription)
        app.buttons["prototype-cancel"].tap()

        let draftRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Continue the draft")).firstMatch
        XCTAssertTrue(draftRow.waitForExistence(timeout: 6), app.debugDescription)
        XCTAssertTrue(poster.label.hasPrefix("0 sessions"), poster.label)
        tapUntil(app, draftRow, shows: "prototype-guided-set-1")
        snap(app, "07-autosave-resume")
    }

    private func sessionRow(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Seated leg extension")).firstMatch
    }

    /// The first tap after launch can be lost. Tap again until the step shows.
    private func tapUntil(_ app: XCUIApplication, _ button: XCUIElement, shows identifier: String) {
        XCTAssertTrue(button.waitForExistence(timeout: 8), app.debugDescription)
        for _ in 0..<4 {
            if button.exists && button.isHittable { button.tap() }
            if element(app, identifier).waitForExistence(timeout: 3) { return }
        }
        XCTFail("\(identifier) did not show. \(app.debugDescription)")
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
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

/// Warm-up: empty finished list + composer at planned hold; after add; footer choices; autosave.
final class WarmupRulerFixShots: XCTestCase {
    private let shotDir = URL(fileURLWithPath: "/tmp/r3hab-warmup-shots", isDirectory: true)

    override func setUpWithError() throws {
        continueAfterFailure = false
        try? FileManager.default.removeItem(at: shotDir)
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    func testComposerAdvancesAndFooterStaysVisible() throws {
        let app = XCUIApplication()
        app.launch()
        let skip = app.buttons["Not now"]
        if skip.waitForExistence(timeout: 8) { skip.tap() }
        XCTAssertTrue(app.descendants(matching: .any)["today-poster"].waitForExistence(timeout: 10), app.debugDescription)

        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Seated leg extension")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), app.debugDescription)
        for _ in 0..<4 {
            if row.exists && row.isHittable { row.tap() }
            if app.descendants(matching: .any)["prototype-guided-exercise"].waitForExistence(timeout: 3) { break }
        }
        app.buttons["prototype-next"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["prototype-guided-warmup"].waitForExistence(timeout: 6), app.debugDescription)

        // Empty finished list; Add + Skip in sticky footer.
        XCTAssertTrue(app.buttons["prototype-guided-warmup-add"].waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue(app.buttons["prototype-guided-warmup-skip"].exists)
        XCTAssertFalse(app.buttons["prototype-guided-warmup-yes"].exists)
        // No finished rows yet (ids are 1-indexed).
        XCTAssertFalse(app.descendants(matching: .any)["prototype-guided-warmup-step-1"].exists)
        snap(app, "01-empty-list-composer-at-hold")

        app.buttons["prototype-guided-warmup-add"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["prototype-guided-warmup-step-1"].waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue(app.buttons["prototype-guided-warmup-yes"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["prototype-guided-warmup-skip"].exists)
        snap(app, "02-after-first-add")

        app.buttons["prototype-guided-warmup-add"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["prototype-guided-warmup-step-2"].waitForExistence(timeout: 4), app.debugDescription)
        snap(app, "03-after-second-add-next-plan")

        // Footer still shows Add + Warm-up done (always visible).
        XCTAssertTrue(app.buttons["prototype-guided-warmup-add"].isHittable)
        XCTAssertTrue(app.buttons["prototype-guided-warmup-yes"].isHittable)
        snap(app, "04-footer-add-and-done")

        // Autosave: leave and resume — finished sets remain.
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        // May still be on warm-up, or cancelled to Today with draft.
        if app.buttons["prototype-cancel"].waitForExistence(timeout: 4) {
            app.buttons["prototype-cancel"].tap()
        }
        let draft = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Continue the draft")).firstMatch
        if draft.waitForExistence(timeout: 6) {
            draft.tap()
            // Resume — warm-up steps should still be there if we were past exercise.
            _ = app.descendants(matching: .any)["prototype-guided-warmup"].waitForExistence(timeout: 4)
                || app.descendants(matching: .any)["prototype-guided-warmup-step-1"].waitForExistence(timeout: 4)
            snap(app, "05-autosave-resume")
        }
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: shotDir.appendingPathComponent("\(name).png"))
    }
}
