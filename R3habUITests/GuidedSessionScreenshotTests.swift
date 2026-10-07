import XCTest

/// The guided recorder from Today: record, Save on a set step, resume
/// on the same step, review, and Finish session.
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
        // Three warm-up nodes from the template. Next on each.
        for step in 1...3 {
            XCTAssertTrue(element(app, "prototype-guided-warmup-step-\(step)").waitForExistence(timeout: 4), app.debugDescription)
            app.buttons["prototype-next"].tap()
        }
        XCTAssertTrue(element(app, "prototype-guided-set-1").waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["prototype-next"].tap()
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

        // 2. Save (top bar) on a set step: keeps the progress and closes.
        let saveDraft = app.buttons["guided-save-draft"]
        XCTAssertTrue(saveDraft.exists, app.debugDescription)
        snap(app, "02-save-draft-on-set-step")
        saveDraft.tap()

        // 3. Today shows the draft, not a complete session.
        XCTAssertTrue(poster.waitForExistence(timeout: 8), app.debugDescription)
        let draftRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "In progress")).firstMatch
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

        for _ in 0..<6 {
            if element(app, "prototype-guided-pain").exists { break }
            app.buttons["prototype-next"].tap()
            _ = element(app, "prototype-guided-pain").waitForExistence(timeout: 1)
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
        XCTAssertTrue(element(app, "prototype-guided-warmup-step-1").waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["prototype-guided-warmup-skip"].tap()
        XCTAssertTrue(element(app, "prototype-guided-set-1").waitForExistence(timeout: 4), app.debugDescription)

        XCUIDevice.shared.press(.home)
        sleep(2)
        app.activate()
        XCTAssertTrue(element(app, "prototype-guided-set-1").waitForExistence(timeout: 6), app.debugDescription)
        // Back to step 1, then Back once more: the sheet closes. The draft stays.
        let back = app.buttons["prototype-back"]
        for _ in 0..<8 where !element(app, "prototype-guided-exercise").exists {
            back.tap()
            _ = element(app, "prototype-guided-exercise").waitForExistence(timeout: 1)
        }
        back.tap()

        let draftRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "In progress")).firstMatch
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

/// Real Settings → Export path into Application Support/Backups, then list / restore / delete.
final class BackupListRealPathShots: XCTestCase {
    private let shotDir = URL(fileURLWithPath: "/tmp/r3hab-backup-shots", isDirectory: true)

    override func setUpWithError() throws {
        continueAfterFailure = false
        try? FileManager.default.removeItem(at: shotDir)
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    func testExportListRestoreDelete() throws {
        let app = XCUIApplication()
        app.launch()
        let skip = app.buttons["Not now"]
        if skip.waitForExistence(timeout: 8) { skip.tap() }
        XCTAssertTrue(app.descendants(matching: .any)["today-poster"].waitForExistence(timeout: 10), app.debugDescription)

        openSettings(app)
        snap(app, "01-settings")
        export(app)
        snap(app, "01b-share-sheet")
        dismissShare(app)

        openBackups(app)
        XCTAssertTrue(row(app).waitForExistence(timeout: 6), "No row after export.\n\(app.debugDescription)")
        XCTAssertEqual(rowCount(app), 1, app.debugDescription)
        snap(app, "02-list-after-first-export")

        // Back to Settings for a second export.
        app.navigationBars["Backups"].buttons["Settings"].tap()
        XCTAssertTrue(exportButton(app).waitForExistence(timeout: 4))
        export(app)
        dismissShare(app)
        openBackups(app)
        waitForRows(app, count: 2)
        XCTAssertEqual(rowCount(app), 2, app.debugDescription)
        snap(app, "03-list-after-second-export")

        // Restore the older row (second in newest-first list).
        row(app, index: 1).tap()
        let confirm = app.alerts["Restore this backup?"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 4), app.debugDescription)
        snap(app, "04-restore-confirmation")
        confirm.buttons["Restore"].tap()
        let done = app.alerts["Restore complete"]
        XCTAssertTrue(done.waitForExistence(timeout: 8), app.debugDescription)
        snap(app, "05-restore-complete")
        done.buttons["OK"].tap()
        waitForRows(app, count: 3)
        XCTAssertEqual(rowCount(app), 3, "Safety backup missing.\n\(app.debugDescription)")
        snap(app, "06-list-with-safety-backup")

        let target = row(app, index: 2)
        target.swipeLeft()
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3), app.debugDescription)
        snap(app, "07-swipe-delete")
        delete.tap()
        waitForRows(app, count: 2)
        XCTAssertEqual(rowCount(app), 2, app.debugDescription)
        snap(app, "08-after-delete")
    }

    private func row(_ app: XCUIApplication, index: Int = 0) -> XCUIElement {
        app.buttons.matching(identifier: "backup-row").element(boundBy: index)
    }

    private func rowCount(_ app: XCUIApplication) -> Int {
        app.buttons.matching(identifier: "backup-row").count
    }

    private func waitForRows(_ app: XCUIApplication, count: Int) {
        let deadline = Date().addingTimeInterval(6)
        while rowCount(app) != count && Date() < deadline { usleep(200_000) }
    }

    private func exportButton(_ app: XCUIApplication) -> XCUIElement {
        let byId = app.buttons["settings-export-backup"]
        if byId.exists { return byId }
        return app.buttons["Export a JSON backup"]
    }

    private func openSettings(_ app: XCUIApplication) {
        let bar = app.navigationBars["Today"]
        XCTAssertTrue(bar.waitForExistence(timeout: 6), app.debugDescription)
        // Trailing gear.
        bar.buttons.element(boundBy: bar.buttons.count - 1).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 6), app.debugDescription)
        // Backup section is below the fold (lazy list).
        scrollUntilExists(app, exportButton(app))
        XCTAssertTrue(exportButton(app).waitForExistence(timeout: 2), app.debugDescription)
    }

    private func export(_ app: XCUIApplication) {
        let button = exportButton(app)
        scrollUntilExists(app, button)
        XCTAssertTrue(button.isHittable || button.exists, app.debugDescription)
        button.tap()
        // Share sheet (Close or Cancel / drag).
        let close = app.buttons["Close"]
        _ = close.waitForExistence(timeout: 8)
        sleep(1)
    }

    private func dismissShare(_ app: XCUIApplication) {
        let close = app.buttons["Close"]
        if close.exists { close.tap(); sleep(1); return }
        let cancel = app.buttons["Cancel"]
        if cancel.exists { cancel.tap(); sleep(1); return }
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        sleep(1)
    }

    private func openBackups(_ app: XCUIApplication) {
        let link = app.descendants(matching: .any)["settings-backups"]
        scrollUntilExists(app, link)
        link.tap()
        XCTAssertTrue(app.navigationBars["Backups"].waitForExistence(timeout: 6), app.debugDescription)
        sleep(1)
    }

    private func scrollUntilExists(_ app: XCUIApplication, _ element: XCUIElement, maxSwipes: Int = 12) {
        if element.exists { return }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 0.6) { return }
        }
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: shotDir.appendingPathComponent("\(name).png"))
    }
}

/// One forward motion: one Next per step, Back in the navigation bar, warm-up nodes, tappable done nodes.
/// Shots land in /tmp/r3hab-forward-shots. Run on a fresh install.
final class SingleForwardShots: XCTestCase {
    private let shotDir = URL(fileURLWithPath: "/tmp/r3hab-forward-shots", isDirectory: true)

    override func setUpWithError() throws {
        continueAfterFailure = false
        try? FileManager.default.removeItem(at: shotDir)
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    func testOneForwardMotion() throws {
        let app = XCUIApplication()
        app.launch()
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 8) { notNow.tap() }
        let poster = element(app, "today-poster")
        XCTAssertTrue(poster.waitForExistence(timeout: 10), app.debugDescription)
        let draftRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "In progress")).firstMatch
        let back = app.buttons["prototype-back"]
        let next = app.buttons["prototype-next"]

        // Back on step 1 with nothing entered: the sheet closes and no draft is made.
        openRecorder(app)
        XCTAssertFalse(app.buttons["prototype-cancel"].exists, "There is no close (x) button")
        XCTAssertTrue(app.buttons["guided-save-draft"].exists)
        back.tap()
        XCTAssertTrue(element(app, "guided-session-screen").waitForNonExistence(timeout: 4), app.debugDescription)
        XCTAssertFalse(draftRow.waitForExistence(timeout: 2), "An untouched log must not make a draft")

        // Warm-up 1: hold, from the template.
        openRecorder(app)
        next.tap()
        XCTAssertTrue(element(app, "prototype-guided-warmup-step-1").waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue(element(app, "prototype-guided-warmup-hold-ruler").exists, "Warm-up 1 is a hold")
        XCTAssertTrue(app.buttons["prototype-guided-warmup-skip"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "prototype-next").count, 1, "One button in the footer")
        snap(app, "01-warmup-1-hold")

        // Warm-up 2: reps, the ramp.
        next.tap()
        XCTAssertTrue(element(app, "prototype-guided-warmup-step-2").waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue(element(app, "prototype-guided-warmup-reps-ruler").exists, "Warm-up 2 is reps, not a hold")
        XCTAssertTrue((element(app, "prototype-guided-warmup-reps-ruler").value as? String ?? "").hasPrefix("3 reps"))
        snap(app, "02-warmup-2-reps-ramp")

        // Warm-up 3: two done nodes on the stepper.
        next.tap()
        XCTAssertTrue(element(app, "prototype-guided-warmup-step-3").waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue((element(app, "prototype-guided-warmup-reps-ruler").value as? String ?? "").hasPrefix("2 reps"))
        XCTAssertTrue(app.buttons["prototype-guided-warmup-node-1"].exists, "Done node 1 opens")
        XCTAssertTrue(app.buttons["prototype-guided-warmup-node-2"].exists, "Done node 2 opens")
        XCTAssertFalse(app.buttons["prototype-guided-warmup-node-3"].exists, "The current node is not a button")
        snap(app, "03-warmup-stepper-two-done")

        // "+" from the last step: an extra step, a copy of the last step.
        app.buttons["prototype-guided-warmup-add"].tap()
        XCTAssertTrue(element(app, "prototype-guided-warmup-step-4").waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue((element(app, "prototype-guided-warmup-reps-ruler").value as? String ?? "").hasPrefix("2 reps"))
        snap(app, "04-plus-extra-step")

        // Tap done node 1: warm-up 1 opens with its values and a Delete control.
        app.buttons["prototype-guided-warmup-node-1"].tap()
        XCTAssertTrue(element(app, "prototype-guided-warmup-step-1").waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue(element(app, "prototype-guided-warmup-hold-ruler").exists)
        let delete = app.buttons["prototype-guided-warmup-remove"]
        XCTAssertTrue(delete.exists, app.debugDescription)
        XCTAssertFalse(app.buttons["prototype-guided-warmup-skip"].exists)
        snap(app, "05-reopened-node-delete")

        // Delete: three nodes stay. The first unfinished step (the extra step) opens.
        delete.tap()
        XCTAssertTrue(element(app, "prototype-guided-warmup-step-3").waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertFalse(element(app, "prototype-guided-warmup-node-4").exists, app.debugDescription)
        XCTAssertFalse(element(app, "prototype-guided-warmup-hold-ruler").exists, "The hold step is gone")
        snap(app, "06-after-delete")

        // Set 1 at the target: one Next. No "Same as target".
        next.tap()
        XCTAssertTrue(element(app, "prototype-guided-set-1").waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertFalse(app.buttons["prototype-guided-same-as-target"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "prototype-next").count, 1)
        snap(app, "07-set-at-target")

        // Set 1 changed: the delta label shows. Next records the shown values.
        let ruler = element(app, "prototype-guided-set-1-load-ruler")
        let atTarget = ruler.value as? String ?? ""
        let start = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: start.withOffset(CGVector(dx: -45, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.4)
        sleep(1)
        let changed = ruler.value as? String ?? ""
        XCTAssertNotEqual(changed, atTarget, "The drag must change the load")
        snap(app, "08-set-changed")
        next.tap()
        XCTAssertTrue(element(app, "prototype-guided-set-2").waitForExistence(timeout: 4), app.debugDescription)

        // Tap done set node 1: set 1 opens with the recorded values.
        app.buttons["prototype-guided-set-node-1"].tap()
        XCTAssertTrue(element(app, "prototype-guided-set-1").waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertEqual(element(app, "prototype-guided-set-1-load-ruler").value as? String, changed)
        snap(app, "09-set-stepper-tapped-done-node")
        // Next goes back to the first unfinished step: set 2.
        next.tap()
        XCTAssertTrue(element(app, "prototype-guided-set-2").waitForExistence(timeout: 4), app.debugDescription)

        // Back from set 2: set 1 with its values kept.
        back.tap()
        XCTAssertTrue(element(app, "prototype-guided-set-1").waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertEqual(element(app, "prototype-guided-set-1-load-ruler").value as? String, changed, "Back does not revert")
        snap(app, "10-back-from-set-values-kept")

        // Back to step 1, then Back once more: the draft is saved and the sheet closes.
        for _ in 0..<8 where !element(app, "prototype-guided-exercise").exists {
            back.tap()
            _ = element(app, "prototype-guided-exercise").waitForExistence(timeout: 1)
        }
        back.tap()
        XCTAssertTrue(element(app, "guided-session-screen").waitForNonExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue(draftRow.waitForExistence(timeout: 6), app.debugDescription)
        XCTAssertTrue(poster.label.hasPrefix("0 sessions"), poster.label)
        snap(app, "11-today-draft-after-back")

        // Resume opens at the first unfinished step with the values.
        draftRow.tap()
        XCTAssertTrue(element(app, "prototype-guided-set-2").waitForExistence(timeout: 6), app.debugDescription)
        app.buttons["prototype-guided-set-node-1"].tap()
        XCTAssertEqual(element(app, "prototype-guided-set-1-load-ruler").value as? String, changed)
        XCTAssertFalse(element(app, "prototype-guided-warmup-node-4").exists)
    }

    private func openRecorder(_ app: XCUIApplication) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Seated leg extension")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), app.debugDescription)
        for _ in 0..<4 {
            if row.exists && row.isHittable { row.tap() }
            if element(app, "prototype-guided-exercise").waitForExistence(timeout: 3) { return }
        }
        XCTFail("The recorder did not open. \(app.debugDescription)")
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: shotDir.appendingPathComponent("\(name).png"))
    }
}

/// Save keeps the progress and closes. Today shows "In progress". Only Finish session completes.
/// Shots land in /tmp/r3hab-save-shots. Run on a fresh install.
final class SaveAndFinishShots: XCTestCase {
    private let shotDir = URL(fileURLWithPath: "/tmp/r3hab-save-shots", isDirectory: true)

    override func setUpWithError() throws {
        continueAfterFailure = false
        try? FileManager.default.removeItem(at: shotDir)
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    func testSaveThenFinishSession() throws {
        let app = XCUIApplication()
        app.launch()
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 8) { notNow.tap() }
        let poster = element(app, "today-poster")
        XCTAssertTrue(poster.waitForExistence(timeout: 10), app.debugDescription)
        let next = app.buttons["prototype-next"]
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Seated leg extension")).firstMatch

        // Top bar: Back, the title, Save. No step dots.
        tapUntil(app, row, shows: "prototype-guided-exercise")
        let save = app.navigationBars.buttons["Save"]
        XCTAssertTrue(save.exists, app.debugDescription)
        XCTAssertFalse(app.buttons["Save draft"].exists)
        XCTAssertTrue(app.navigationBars.staticTexts["Record session"].exists, app.debugDescription)
        XCTAssertFalse(element(app, "prototype-progress").exists, "The step dots are gone")

        // Warm-up 3: two done nodes, the current node, then "+" with no line before it.
        next.tap()
        for step in 1...2 {
            XCTAssertTrue(element(app, "prototype-guided-warmup-step-\(step)").waitForExistence(timeout: 4), app.debugDescription)
            next.tap()
        }
        XCTAssertTrue(element(app, "prototype-guided-warmup-step-3").waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue(app.buttons["prototype-guided-warmup-add"].exists)
        snap(app, "01-warmup-stepper-no-stub")

        // Set 1, then set 2. Save on set 2.
        next.tap()
        XCTAssertTrue(element(app, "prototype-guided-set-1").waitForExistence(timeout: 4), app.debugDescription)
        snap(app, "02-top-bar-save")
        next.tap()
        XCTAssertTrue(element(app, "prototype-guided-set-2").waitForExistence(timeout: 4), app.debugDescription)
        save.tap()
        XCTAssertTrue(element(app, "guided-session-screen").waitForNonExistence(timeout: 6), app.debugDescription)

        // Today: the session is in progress, not complete. No reminders yet.
        let inProgress = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "In progress")).firstMatch
        XCTAssertTrue(inProgress.waitForExistence(timeout: 6), app.debugDescription)
        XCTAssertTrue(poster.label.hasPrefix("0 sessions"), poster.label)
        XCTAssertFalse(app.buttons["Record the 24-hour response"].exists)
        XCTAssertFalse(app.buttons["Record pain after"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "draft")).firstMatch.exists,
                       "Today does not say draft")
        snap(app, "03-today-in-progress")

        // Resume at the first unfinished step: set 2. Set 1 is done.
        tapUntil(app, inProgress, shows: "prototype-guided-set-2")
        XCTAssertTrue(app.buttons["prototype-guided-set-node-1"].exists, app.debugDescription)
        snap(app, "04-resumed-session")

        // Go on to Review. Only Finish session completes the session.
        for _ in 0..<6 where !element(app, "prototype-guided-pain").exists {
            next.tap()
            _ = element(app, "prototype-guided-pain").waitForExistence(timeout: 1)
        }
        XCTAssertTrue(element(app, "prototype-guided-pain").waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["prototype-pain-chip-2"].tap()
        next.tap()
        XCTAssertTrue(element(app, "prototype-guided-notes").waitForExistence(timeout: 4), app.debugDescription)
        next.tap()
        XCTAssertTrue(element(app, "prototype-guided-review").waitForExistence(timeout: 4), app.debugDescription)
        let finish = app.buttons["prototype-save"]
        XCTAssertEqual(finish.label, "Finish session")
        snap(app, "05-review-finish-session")
        finish.tap()
        XCTAssertTrue(element(app, "guided-session-screen").waitForNonExistence(timeout: 6), app.debugDescription)
        let deadline = Date().addingTimeInterval(6)
        while !poster.label.hasPrefix("1 session") && Date() < deadline { usleep(250_000) }
        XCTAssertTrue(poster.label.hasPrefix("1 session"), poster.label)
        XCTAssertFalse(inProgress.exists, "A finished session is not in progress")
        snap(app, "06-today-after-finish")
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
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: shotDir.appendingPathComponent("\(name).png"))
    }
}

/// Morning pain uses the swipe ruler: Today, the prefill from yesterday, and History edit.
/// Shots land in /tmp/r3hab-morning-shots. Run on a fresh install.
final class MorningRulerShots: XCTestCase {
    private let shotDir = URL(fileURLWithPath: "/tmp/r3hab-morning-shots", isDirectory: true)

    override func setUpWithError() throws {
        continueAfterFailure = false
        try? FileManager.default.removeItem(at: shotDir)
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    func testMorningPainRuler() throws {
        let app = XCUIApplication()
        app.launch()
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 8) { notNow.tap() }
        XCTAssertTrue(element(app, "today-poster").waitForExistence(timeout: 10), app.debugDescription)
        let ruler = element(app, "morning-pain-ruler")

        // 1. No yesterday value: the ruler opens at 0. The old 0-10 buttons are gone.
        let record = app.buttons["Record morning pain"]
        XCTAssertTrue(record.waitForExistence(timeout: 6), app.debugDescription)
        record.tap()
        XCTAssertTrue(ruler.waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue(value(ruler).hasPrefix("0 of 10"), value(ruler))
        XCTAssertFalse(app.buttons["Knee resting pain 1"].exists, "The 0-10 buttons are replaced")
        snap(app, "01-today-morning-ruler-at-0")

        // 2. Swipe to change the value.
        drag(ruler, ticks: 3)
        XCTAssertFalse(value(ruler).hasPrefix("0 of 10"), "The swipe changes the value: \(value(ruler))")
        let recorded = String(value(ruler).prefix(while: { $0 != " " }))
        snap(app, "02-today-morning-ruler-swiped")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(ruler.waitForNonExistence(timeout: 6), app.debugDescription)
        let dismissNudge = app.buttons["OK"]
        if dismissNudge.waitForExistence(timeout: 1) { dismissNudge.tap() }
        let morningRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Morning pain")).firstMatch
        XCTAssertTrue(morningRow.waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue(morningRow.label.contains(recorded), morningRow.label)

        // 3. A past day: the ruler opens at the morning value of the day before it (today's value is not used).
        //    History: add a check-in for 2 days ago after one for 3 days ago.
        app.tabBars.buttons["History"].tap()
        addPastCheckIn(app, daysAgo: 3, ticks: 2)
        let threeDaysAgo = lastSavedMorning
        openPastCheckIn(app, daysAgo: 2)
        XCTAssertTrue(ruler.waitForExistence(timeout: 4), app.debugDescription)
        // A full check-in does not record a morning value until the user moves the ruler.
        XCTAssertTrue(value(ruler).contains("Not recorded"), value(ruler))
        snap(app, "03-history-new-day-not-recorded")
        ruler.tap()
        XCTAssertTrue(value(ruler).hasPrefix("\(threeDaysAgo) of 10"), "Prefill from the day before: \(value(ruler))")
        XCTAssertTrue(value(ruler).contains("Same as the day before"), value(ruler))
        snap(app, "04-history-prefill-from-day-before")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(ruler.waitForNonExistence(timeout: 6), app.debugDescription)
        if dismissNudge.waitForExistence(timeout: 1) { dismissNudge.tap() }

        // 4. History edit of today's check-in: the ruler shows the saved value.
        let todayRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Morning pain \(recorded)")).firstMatch
        XCTAssertTrue(todayRow.waitForExistence(timeout: 6), app.debugDescription)
        todayRow.tap()
        XCTAssertTrue(ruler.waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue(value(ruler).hasPrefix("\(recorded) of 10"), value(ruler))
        snap(app, "05-history-edit-ruler")
    }

    private var lastSavedMorning = ""

    private func addPastCheckIn(_ app: XCUIApplication, daysAgo: Int, ticks: Int) {
        openPastCheckIn(app, daysAgo: daysAgo)
        let ruler = element(app, "morning-pain-ruler")
        XCTAssertTrue(ruler.waitForExistence(timeout: 4), app.debugDescription)
        drag(ruler, ticks: ticks)
        lastSavedMorning = String(value(ruler).prefix(while: { $0 != " " }))
        XCTAssertNotEqual(lastSavedMorning, "\u{2014}", value(ruler))
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(ruler.waitForNonExistence(timeout: 6), app.debugDescription)
        let ok = app.buttons["OK"]
        if ok.waitForExistence(timeout: 1) { ok.tap() }
    }

    /// History: + → Add a past check-in → pick the date → Continue.
    private func openPastCheckIn(_ app: XCUIApplication, daysAgo: Int) {
        let add = app.buttons["Add a past day"]
        XCTAssertTrue(add.waitForExistence(timeout: 6), app.debugDescription)
        add.tap()
        let checkIn = app.buttons["Add a past check-in"]
        if checkIn.waitForExistence(timeout: 2) { checkIn.tap() }
        let target = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let picker = app.datePickers.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 4), app.debugDescription)
        picker.tap()
        let dayNumber = Calendar.current.component(.day, from: target)
        let monthDiffers = Calendar.current.component(.month, from: target) != Calendar.current.component(.month, from: Date())
        if monthDiffers {
            app.buttons["Previous Month"].tap()
        }
        let cell = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", " \(dayNumber)")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 4), app.debugDescription)
        cell.tap()
        // Close the calendar popover.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        app.navigationBars.buttons["Continue"].tap()
        // The full check-in can open the Apple Health explainer first.
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 3) { notNow.tap() }
        _ = element(app, "morning-pain-ruler").waitForExistence(timeout: 4)
        sleep(1)
    }

    private func drag(_ ruler: XCUIElement, ticks: Int) {
        let start = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        let end = start.withOffset(CGVector(dx: -28 * CGFloat(ticks), dy: 0))
        start.press(forDuration: 0.15, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.4)
        sleep(1)
    }

    private func value(_ element: XCUIElement) -> String {
        element.value as? String ?? ""
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: shotDir.appendingPathComponent("\(name).png"))
    }
}

/// Move back and forth between the done steps and the furthest step.
/// Edge swipes change the step. A drag on a ruler moves only the ruler.
/// Shots land in /tmp/r3hab-step-nav-shots. Run on a fresh install.
final class StepNavShots: XCTestCase {
    private let shotDir = URL(fileURLWithPath: "/tmp/r3hab-step-nav-shots", isDirectory: true)

    override func setUpWithError() throws {
        continueAfterFailure = false
        try? FileManager.default.removeItem(at: shotDir)
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    func testSwipeBetweenDoneStepsAndTheFurthestStep() throws {
        let app = XCUIApplication()
        app.launch()
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 8) { notNow.tap() }
        XCTAssertTrue(element(app, "today-poster").waitForExistence(timeout: 10), app.debugDescription)
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Seated leg extension")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), app.debugDescription)
        for _ in 0..<4 where !element(app, "prototype-guided-exercise").exists {
            if row.isHittable { row.tap() }
            _ = element(app, "prototype-guided-exercise").waitForExistence(timeout: 3)
        }
        let next = app.buttons["prototype-next"]
        // Exercise, three warm-up steps, set 1, set 2: the furthest step is set 3.
        for _ in 0..<6 { next.tap(); usleep(400_000) }
        XCTAssertTrue(element(app, "prototype-guided-set-3").waitForExistence(timeout: 4), app.debugDescription)

        // Edge swipe back: set 2.
        edgeSwipe(app, back: true)
        XCTAssertTrue(element(app, "prototype-guided-set-2").waitForExistence(timeout: 4), app.debugDescription)
        snap(app, "01-swipe-back-to-set-2")

        // A drag on the ruler moves the ruler. The step does not change.
        let ruler = element(app, "prototype-guided-set-2-load-ruler")
        let before = ruler.value as? String ?? ""
        let start = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        start.press(forDuration: 0.15, thenDragTo: start.withOffset(CGVector(dx: -90, dy: 0)), withVelocity: .fast, thenHoldForDuration: 0.2)
        sleep(1)
        let changed = ruler.value as? String ?? ""
        XCTAssertNotEqual(before, changed, "The drag moves the ruler")
        XCTAssertTrue(element(app, "prototype-guided-set-2").exists, "A drag on a ruler does not change the step")
        snap(app, "02-ruler-drag-keeps-step")

        // Edge swipe forward twice: set 3, then no skip ahead past the furthest step.
        edgeSwipe(app, back: false)
        XCTAssertTrue(element(app, "prototype-guided-set-3").waitForExistence(timeout: 4), app.debugDescription)
        edgeSwipe(app, back: false)
        sleep(1)
        XCTAssertTrue(element(app, "prototype-guided-set-3").exists, "A swipe does not go past the furthest step")
        XCTAssertFalse(element(app, "prototype-guided-pain").exists)
        snap(app, "03-forward-stops-at-furthest")

        // Save and resume: the furthest step opens, and the change on set 2 stays.
        app.buttons["guided-save-draft"].tap()
        let inProgress = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "In progress")).firstMatch
        XCTAssertTrue(inProgress.waitForExistence(timeout: 6), app.debugDescription)
        for _ in 0..<4 where !element(app, "prototype-guided-set-3").exists {
            if inProgress.isHittable { inProgress.tap() }
            _ = element(app, "prototype-guided-set-3").waitForExistence(timeout: 3)
        }
        XCTAssertTrue(element(app, "prototype-guided-set-3").exists, app.debugDescription)
        edgeSwipe(app, back: true)
        XCTAssertTrue(element(app, "prototype-guided-set-2").waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertEqual(element(app, "prototype-guided-set-2-load-ruler").value as? String, changed, "The edit does not revert")
        snap(app, "04-resume-keeps-edit")
    }

    /// A swipe that starts at the screen edge, outside the rulers.
    private func edgeSwipe(_ app: XCUIApplication, back: Bool) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: back ? 0.02 : 0.98, dy: 0.55))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: back ? 0.6 : 0.4, dy: 0.55))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .fast, thenHoldForDuration: 0)
        usleep(500_000)
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: shotDir.appendingPathComponent("\(name).png"))
    }
}
