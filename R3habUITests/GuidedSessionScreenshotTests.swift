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

        // Footer still shows Add + Done (always visible).
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

/// The two-button footer on each screen that uses it. Back is the chevron in the navigation bar.
/// Shots land in /tmp/r3hab-footer-shots. Run on a fresh install so onboarding shows.
final class FooterShots: XCTestCase {
    private let shotDir = URL(fileURLWithPath: "/tmp/r3hab-footer-shots", isDirectory: true)

    override func setUpWithError() throws {
        continueAfterFailure = false
        try? FileManager.default.removeItem(at: shotDir)
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    func testFooterOnEachScreen() throws {
        let app = XCUIApplication()
        app.launch()

        // Onboarding: Not now on the left, Continue on the right.
        let notNow = app.buttons["Not now"]
        if notNow.waitForExistence(timeout: 8) {
            snap(app, "01-onboarding")
            XCTAssertTrue(app.buttons["Continue"].exists, app.debugDescription)
            XCTAssertEqual(notNow.frame.height, app.buttons["Continue"].frame.height, accuracy: 1)
            XCTAssertLessThan(notNow.frame.minX, app.buttons["Continue"].frame.minX)
            notNow.tap()
        }
        let poster = element(app, "today-poster")
        XCTAssertTrue(poster.waitForExistence(timeout: 10), app.debugDescription)

        // Exercise: one Next. No Back on step 1.
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Seated leg extension")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8), app.debugDescription)
        for _ in 0..<4 {
            if row.exists && row.isHittable { row.tap() }
            if element(app, "prototype-guided-exercise").waitForExistence(timeout: 3) { break }
        }
        XCTAssertTrue(app.buttons["prototype-cancel"].exists, app.debugDescription)
        XCTAssertTrue(app.buttons["guided-save-draft"].exists, app.debugDescription)
        XCTAssertFalse(app.buttons["prototype-back"].isHittable)
        snap(app, "02-exercise")
        app.buttons["prototype-next"].tap()

        // Warm-up, no sets: Add warm-up and Skip.
        XCTAssertTrue(element(app, "prototype-guided-warmup").waitForExistence(timeout: 4), app.debugDescription)
        let add = app.buttons["prototype-guided-warmup-add"]
        XCTAssertTrue(add.waitForExistence(timeout: 4), app.debugDescription)
        let skip = app.buttons["prototype-guided-warmup-skip"]
        XCTAssertTrue(skip.exists, app.debugDescription)
        XCTAssertEqual(skip.label, "Skip")
        XCTAssertEqual(add.frame.height, skip.frame.height, accuracy: 1)
        XCTAssertEqual(add.frame.midY, skip.frame.midY, accuracy: 1)
        XCTAssertLessThan(add.frame.minX, skip.frame.minX)
        XCTAssertTrue(app.buttons["prototype-back"].isHittable)
        snap(app, "03-warmup-no-sets")

        // Warm-up, after two adds: Add warm-up and Done.
        add.tap()
        XCTAssertTrue(element(app, "prototype-guided-warmup-step-1").waitForExistence(timeout: 4), app.debugDescription)
        add.tap()
        XCTAssertTrue(element(app, "prototype-guided-warmup-step-2").waitForExistence(timeout: 4), app.debugDescription)
        let done = app.buttons["prototype-guided-warmup-yes"]
        XCTAssertTrue(done.waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual(done.label, "Done")
        XCTAssertFalse(skip.exists)
        snap(app, "04-warmup-after-adding-sets")
        done.tap()

        // Set 1 at the target: one button.
        XCTAssertTrue(element(app, "prototype-guided-set-1").waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertTrue(app.buttons["prototype-guided-same-as-target"].exists)
        XCTAssertFalse(app.buttons["prototype-next"].exists)
        snap(app, "05-set-at-target")

        // Set 1 changed: Same as target on the left, Next on the right.
        let ruler = element(app, "prototype-guided-set-1-load-ruler")
        XCTAssertTrue(ruler.waitForExistence(timeout: 4), app.debugDescription)
        let start = ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.15, thenDragTo: start.withOffset(CGVector(dx: -45, dy: 0)), withVelocity: .slow, thenHoldForDuration: 0.4)
        let next = app.buttons["prototype-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 3), app.debugDescription)
        let same = app.buttons["prototype-guided-same-as-target"]
        XCTAssertEqual(same.frame.height, next.frame.height, accuracy: 1)
        XCTAssertLessThan(same.frame.minX, next.frame.minX)
        snap(app, "06-set-changed")
        next.tap()
        XCTAssertTrue(element(app, "prototype-guided-set-2").waitForExistence(timeout: 4), app.debugDescription)

        // Back chevron: set 2 to set 1.
        app.buttons["prototype-back"].tap()
        XCTAssertTrue(element(app, "prototype-guided-set-1").waitForExistence(timeout: 4), app.debugDescription)

        // Step dots: a later dot does nothing. A completed dot opens that step.
        let laterDot = element(app, "prototype-progress-step-5")
        if laterDot.exists { laterDot.tap() }
        XCTAssertTrue(element(app, "prototype-guided-set-1").exists, "A later dot must not move forward")
        element(app, "prototype-progress-step-1").tap()
        XCTAssertTrue(element(app, "prototype-guided-exercise").waitForExistence(timeout: 4), app.debugDescription)
        snap(app, "07-dot-jump-to-step-1")

        // Forward to pain.
        app.buttons["prototype-next"].tap()
        XCTAssertTrue(app.buttons["prototype-guided-warmup-yes"].waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["prototype-guided-warmup-yes"].tap()
        for _ in 0..<8 {
            if element(app, "prototype-guided-pain").exists { break }
            let nextSet = app.buttons["prototype-next"]
            let sameSet = app.buttons["prototype-guided-same-as-target"]
            if nextSet.exists { nextSet.tap() } else if sameSet.waitForExistence(timeout: 2) { sameSet.tap() }
            sleep(1)
        }
        XCTAssertTrue(element(app, "prototype-guided-pain").waitForExistence(timeout: 4), app.debugDescription)
        XCTAssertFalse(app.buttons["prototype-next"].isEnabled, "Next waits for a pain score")
        snap(app, "08-pain-no-score")
        app.buttons["prototype-pain-chip-2"].tap()
        XCTAssertTrue(app.buttons["prototype-next"].isEnabled)
        snap(app, "09-pain")
        app.buttons["prototype-next"].tap()
        XCTAssertTrue(element(app, "prototype-guided-notes").waitForExistence(timeout: 4), app.debugDescription)
        snap(app, "10-notes")
        app.buttons["prototype-next"].tap()
        XCTAssertTrue(element(app, "prototype-guided-review").waitForExistence(timeout: 4), app.debugDescription)
        snap(app, "11-review")

        // Cancel (x) closes without a save.
        app.buttons["prototype-cancel"].tap()
        XCTAssertTrue(poster.waitForExistence(timeout: 8), app.debugDescription)

        // Manual session form from Log: Save, then Save draft next to it after a change.
        openPastSession(app)
        let save = app.buttons["Save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 6), app.debugDescription)
        snap(app, "12-session-form")
        XCTAssertFalse(app.buttons["Save draft"].exists, "Save draft waits for a change")
        let legPress = app.buttons["Leg press"]
        XCTAssertTrue(legPress.waitForExistence(timeout: 3), app.debugDescription)
        legPress.tap()
        let saveDraft = app.buttons["Save draft"]
        XCTAssertTrue(saveDraft.waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertEqual(saveDraft.frame.height, save.frame.height, accuracy: 1)
        XCTAssertLessThan(saveDraft.frame.minX, save.frame.minX)
        sleep(1)
        snap(app, "13-session-form-changed")
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists { cancel.tap() }
        sleep(1)

        // Apple Health explainer from Settings: Not now on the left, Continue on the right.
        openHealthExplainer(app)
    }

    private func openPastSession(_ app: XCUIApplication) {
        let logTab = app.tabBars.buttons.element(boundBy: 1)
        XCTAssertTrue(logTab.waitForExistence(timeout: 4), app.debugDescription)
        logTab.tap()
        let addPast = app.buttons["Add a past day"]
        XCTAssertTrue(addPast.waitForExistence(timeout: 6), app.debugDescription)
        addPast.tap()
        let pastSession = app.buttons["Add a past session"]
        XCTAssertTrue(pastSession.waitForExistence(timeout: 4), app.debugDescription)
        pastSession.tap()
        let cont = app.buttons["Continue"]
        XCTAssertTrue(cont.waitForExistence(timeout: 4), app.debugDescription)
        cont.tap()
    }

    private func openHealthExplainer(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 0).tap()
        let bar = app.navigationBars["Today"]
        XCTAssertTrue(bar.waitForExistence(timeout: 6), app.debugDescription)
        bar.buttons.element(boundBy: bar.buttons.count - 1).tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 6), app.debugDescription)
        let connect = app.buttons["Connect"]
        for _ in 0..<6 where !connect.exists { app.swipeUp() }
        guard connect.waitForExistence(timeout: 2) else {
            snap(app, "14-settings-no-connect")
            return
        }
        connect.tap()
        let explainer = element(app, "appleHealthPermission")
        XCTAssertTrue(explainer.waitForExistence(timeout: 4), app.debugDescription)
        snap(app, "14-apple-health-explainer")
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: shotDir.appendingPathComponent("\(name).png"))
    }
}
