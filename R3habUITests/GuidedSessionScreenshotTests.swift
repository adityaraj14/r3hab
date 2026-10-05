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
