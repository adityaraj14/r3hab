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

    func testKneeTrackIsAlreadyNormalized() {
        XCTAssertFalse(SettingsSeedPolicy.shouldNormalizeActiveTracks("knee"))
        XCTAssertFalse(
            SettingsSeedPolicy.shouldNormalizeActiveTracks(RehabTrackID.knee.rawValue)
        )
    }

    func testQLTrackIsAlreadyNormalized() {
        XCTAssertFalse(SettingsSeedPolicy.shouldNormalizeActiveTracks("ql"))
        XCTAssertFalse(
            SettingsSeedPolicy.shouldNormalizeActiveTracks(RehabTrackID.ql.rawValue)
        )
    }

    func testLeftoverDualTrackCSVNeedsWrite() {
        XCTAssertTrue(SettingsSeedPolicy.shouldNormalizeActiveTracks("knee,lowerBack"))
        XCTAssertTrue(SettingsSeedPolicy.shouldNormalizeActiveTracks("lowerBack"))
        XCTAssertTrue(SettingsSeedPolicy.shouldNormalizeActiveTracks(""))
    }

    func testRetiredKneePrimaryLoadNeedsAWrite() {
        XCTAssertTrue(SettingsSeedPolicy.shouldRemapPrimaryLoad("spanish-squat", track: .knee))
        XCTAssertTrue(SettingsSeedPolicy.shouldRemapPrimaryLoad("wall-sit", track: .knee))
        XCTAssertFalse(SettingsSeedPolicy.shouldRemapPrimaryLoad("seated-extension", track: .knee))
        XCTAssertFalse(SettingsSeedPolicy.shouldRemapPrimaryLoad("leg-press", track: .knee))
    }

    func testIdempotentOpenDoesNotNeedAWrite() {
        // The foreground path used to assign activeTracksCSV and save on every
        // ensureSettings() call. After the first migration, both predicates
        // must be false so resume does not dirty SQLite (0xdead10cc).
        let alreadyMigrated = !SettingsSeedPolicy.shouldMigrateLegacyPMReminder(
            hour: SettingsSeedPolicy.currentPMReminderHour,
            minute: SettingsSeedPolicy.currentPMReminderMinute
        )
        let alreadyKnee = !SettingsSeedPolicy.shouldNormalizeActiveTracks("knee")
        let alreadyLoad = !SettingsSeedPolicy.shouldRemapPrimaryLoad("seated-extension", track: .knee)
        XCTAssertTrue(alreadyMigrated && alreadyKnee && alreadyLoad)
    }
}
