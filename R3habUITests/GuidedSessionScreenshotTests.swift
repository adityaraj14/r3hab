import XCTest

// Today opens Today's session, and that page opens SessionEditor from a plan row. The guided recorder is only
// for an older guided draft, so the tests that started that recorder from Today
// are gone. Backup and the morning ruler still run.

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

