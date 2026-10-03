import XCTest

/// Screenshots of the three Debug logging prototypes for review.
/// Shots land in /tmp/r3hab-prototypes. The Prototypes menu is in Debug and Release (TestFlight) builds.
final class SessionPrototypeScreenshotTests: XCTestCase {
    private let shotDir = URL(fileURLWithPath: "/tmp/r3hab-prototypes", isDirectory: true)

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)
    }

    func testPrototypeScreens() throws {
        let app = XCUIApplication()
        app.launch()

        let skip = app.buttons["Not now"]
        if skip.waitForExistence(timeout: 8) {
            skip.tap()
        }
        XCTAssertTrue(app.descendants(matching: .any)["today-poster"].waitForExistence(timeout: 10), app.debugDescription)

        openPrototype(app, title: "Guided steps")
        XCTAssertTrue(element(app, "prototype-guided-exercise").waitForExistence(timeout: 6), app.debugDescription)
        snap(app, "prototype-a-exercise")
        app.buttons["prototype-next"].tap()
        XCTAssertTrue(element(app, "prototype-guided-warmup").waitForExistence(timeout: 4), app.debugDescription)
        snap(app, "prototype-a-warmup")
        app.buttons["prototype-guided-warmup-yes"].tap()
        XCTAssertTrue(element(app, "prototype-guided-set-1").waitForExistence(timeout: 4), app.debugDescription)
        snap(app, "prototype-a-set")
        for _ in 0..<6 {
            let same = app.buttons["prototype-guided-same-as-target"]
            guard same.waitForExistence(timeout: 2) else { break }
            same.tap()
        }
        XCTAssertTrue(element(app, "prototype-guided-pain").waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["prototype-pain-chip-2"].tap()
        snap(app, "prototype-a-pain")
        app.buttons["prototype-cancel"].tap()

        openPrototype(app, title: "Live tracker")
        XCTAssertTrue(element(app, "prototype-live-dose").waitForExistence(timeout: 6), app.debugDescription)
        snap(app, "prototype-b-live")
        var liveGuard = 0
        var snappedRest = false
        while app.buttons["prototype-live-done-set"].exists && liveGuard < 8 {
            app.buttons["prototype-live-done-set"].tap()
            if app.buttons["prototype-live-skip-rest"].waitForExistence(timeout: 2) {
                if !snappedRest {
                    snap(app, "prototype-b-rest")
                    snappedRest = true
                }
                app.buttons["prototype-live-skip-rest"].tap()
            }
            liveGuard += 1
        }
        XCTAssertTrue(snappedRest, app.debugDescription)
        XCTAssertTrue(element(app, "prototype-live-pain").waitForExistence(timeout: 4), app.debugDescription)
        snap(app, "prototype-b-pain")
        app.buttons["prototype-cancel"].tap()

        openPrototype(app, title: "Quick log")
        XCTAssertTrue(element(app, "prototype-quick-plan").waitForExistence(timeout: 6), app.debugDescription)
        snap(app, "prototype-c-ask")
        app.buttons["prototype-quick-adjust"].tap()
        XCTAssertTrue(element(app, "prototype-quick-adjust-panel").waitForExistence(timeout: 4), app.debugDescription)
        snap(app, "prototype-c-adjust")
        app.buttons["prototype-back"].tap()
        app.buttons["prototype-quick-yes"].tap()
        XCTAssertTrue(element(app, "prototype-quick-pain").waitForExistence(timeout: 4), app.debugDescription)
        app.buttons["prototype-pain-chip-2"].tap()
        snap(app, "prototype-c-pain")
        app.buttons["prototype-save"].tap()
        let quick = element(app, "prototype-quick-screen")
        XCTAssertTrue(quick.waitForNonExistence(timeout: 6), app.debugDescription)
        snap(app, "prototype-c-saved")
    }

    private func openPrototype(_ app: XCUIApplication, title: String) {
        let menu = app.buttons["session-log-prototype-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 6), app.debugDescription)
        menu.tap()
        let button = app.buttons[title]
        if button.waitForExistence(timeout: 2) {
            button.tap()
            return
        }
        let item = app.menuItems[title]
        XCTAssertTrue(item.waitForExistence(timeout: 2), app.debugDescription)
        item.tap()
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
