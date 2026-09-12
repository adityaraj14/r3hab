import XCTest
@testable import R3hab

final class SettingsSeedPolicyTests: XCTestCase {
    func testLegacyEveningDefaultIsMigrated() {
        XCTAssertTrue(
            SettingsSeedPolicy.shouldMigrateLegacyPMReminder(hour: 21, minute: 0)
        )
    }

    func testCustomEveningTimeIsLeftAlone() {
        XCTAssertFalse(
            SettingsSeedPolicy.shouldMigrateLegacyPMReminder(hour: 21, minute: 15)
        )
        XCTAssertFalse(
            SettingsSeedPolicy.shouldMigrateLegacyPMReminder(hour: 18, minute: 30)
        )
        XCTAssertFalse(
            SettingsSeedPolicy.shouldMigrateLegacyPMReminder(hour: 20, minute: 0)
        )
    }

    func testRetiredKneePrimaryLoadNeedsAWrite() {
        XCTAssertTrue(SettingsSeedPolicy.shouldRemapPrimaryLoad("spanish-squat"))
        XCTAssertTrue(SettingsSeedPolicy.shouldRemapPrimaryLoad("wall-sit"))
        XCTAssertFalse(SettingsSeedPolicy.shouldRemapPrimaryLoad("seated-extension"))
        XCTAssertFalse(SettingsSeedPolicy.shouldRemapPrimaryLoad("leg-press"))
    }

    func testRemovedQLLoadsRemapToSeatedExtension() {
        for retired in ["ql-hip-thrust", "ql-side-bend", "ql-walk"] {
            XCTAssertTrue(SettingsSeedPolicy.shouldRemapPrimaryLoad(retired), retired)
            XCTAssertEqual(PrimaryLoadCatalog.normalizedID(retired), "seated-extension", retired)
        }
    }

    func testIdempotentOpenDoesNotNeedAWrite() {
        // The foreground path used to assign settings and save on every
        // ensureSettings() call. After the first migration, every predicate
        // must be false so resume does not dirty SQLite (0xdead10cc).
        let alreadyMigrated = !SettingsSeedPolicy.shouldMigrateLegacyPMReminder(
            hour: SettingsSeedPolicy.currentPMReminderHour,
            minute: SettingsSeedPolicy.currentPMReminderMinute
        )
        let alreadyLoad = !SettingsSeedPolicy.shouldRemapPrimaryLoad("seated-extension")
        let alreadyInjury = !SettingsSeedPolicy.shouldRemapInjury("patellar-tendinopathy")
        XCTAssertTrue(alreadyMigrated && alreadyLoad && alreadyInjury)
    }

    func testRetiredInjuryIDsNeedAWrite() {
        XCTAssertTrue(SettingsSeedPolicy.shouldRemapInjury("jumpers-knee"))
        XCTAssertTrue(SettingsSeedPolicy.shouldRemapInjury("patellar-tendonitis"))
        XCTAssertTrue(SettingsSeedPolicy.shouldRemapInjury("ql-strain"))
        XCTAssertFalse(SettingsSeedPolicy.shouldRemapInjury("patellar-tendinopathy"))
    }
}
