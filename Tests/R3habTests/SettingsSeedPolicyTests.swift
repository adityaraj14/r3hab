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
        let alreadyPhase = RehabPhase.allCases.allSatisfy { !SettingsSeedPolicy.shouldRemapPhase($0.rawValue) }
        XCTAssertTrue(alreadyMigrated && alreadyLoad && alreadyInjury && alreadyPhase)
    }

    func testRemovedPhasesDAndERemapToC() {
        XCTAssertEqual(RehabPhase.allCases, [.aFlareDeLoad, .bIsometrics, .cHeavySlowResistance])
        XCTAssertEqual(RehabPhase.allCases.map(\.rawValue), ["A", "B", "C"])

        for retired in ["D", "E"] {
            XCTAssertTrue(SettingsSeedPolicy.shouldRemapPhase(retired), retired)
            XCTAssertEqual(RehabPhase.normalized(rawValue: retired), .cHeavySlowResistance, retired)
            XCTAssertEqual(RehabPhase.normalizedRawValue(retired), "C", retired)
        }
        for live in ["A", "B", "C"] {
            XCTAssertFalse(SettingsSeedPolicy.shouldRemapPhase(live), live)
            XCTAssertEqual(RehabPhase.normalizedRawValue(live), live)
        }
        // Garbage still lands on the fresh-install default, as before.
        XCTAssertEqual(RehabPhase.normalized(rawValue: ""), .aFlareDeLoad)
        XCTAssertEqual(RehabPhase.normalized(rawValue: "Z"), .aFlareDeLoad)
    }

    func testRetiredInjuryIDsNeedAWrite() {
        XCTAssertTrue(SettingsSeedPolicy.shouldRemapInjury("jumpers-knee"))
        XCTAssertTrue(SettingsSeedPolicy.shouldRemapInjury("patellar-tendonitis"))
        XCTAssertTrue(SettingsSeedPolicy.shouldRemapInjury("ql-strain"))
        XCTAssertFalse(SettingsSeedPolicy.shouldRemapInjury("patellar-tendinopathy"))
    }
}
