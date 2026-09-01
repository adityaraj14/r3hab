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

    func testLeftoverDualTrackCSVNeedsWrite() {
        XCTAssertTrue(SettingsSeedPolicy.shouldNormalizeActiveTracks("knee,lowerBack"))
        XCTAssertTrue(SettingsSeedPolicy.shouldNormalizeActiveTracks("lowerBack"))
        XCTAssertTrue(SettingsSeedPolicy.shouldNormalizeActiveTracks(""))
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
        XCTAssertTrue(alreadyMigrated && alreadyKnee)
    }
}
