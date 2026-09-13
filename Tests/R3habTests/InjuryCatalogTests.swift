import XCTest
@testable import R3hab

final class InjuryCatalogTests: XCTestCase {
    func testCatalogShipsOneKneeInjury() {
        XCTAssertEqual(InjuryCatalog.all.map(\.id), ["patellar-tendinopathy"])
        XCTAssertEqual(
            InjuryCatalog.defaultSelectable.title,
            "Jumper’s knee / patellar tendinopathy / patellar tendonitis"
        )
        XCTAssertTrue(InjuryCatalog.contains("patellar-tendinopathy"))
        XCTAssertFalse(InjuryCatalog.contains("ql-strain"))
        XCTAssertFalse(InjuryCatalog.all.contains { $0.title.contains("QL") })
    }

    func testKneeAliasesRemapToPatellarTendinopathy() {
        XCTAssertEqual(InjuryCatalog.normalizedID("jumpers-knee"), "patellar-tendinopathy")
        XCTAssertEqual(InjuryCatalog.normalizedID("patellar-tendonitis"), "patellar-tendinopathy")
        XCTAssertEqual(InjuryCatalog.definition(for: "jumpers-knee").id, "patellar-tendinopathy")
        XCTAssertTrue(InjuryCatalog.needsRemap("jumpers-knee"))
        XCTAssertTrue(InjuryCatalog.needsRemap("patellar-tendonitis"))
        XCTAssertFalse(InjuryCatalog.needsRemap("patellar-tendinopathy"))
    }

    func testRetiredQLStrainRemapsToKneeOnLaunch() {
        // Existing installs that picked QL strain must open on the knee diary, not crash.
        XCTAssertTrue(InjuryCatalog.retiredIDs.contains("ql-strain"))
        XCTAssertTrue(InjuryCatalog.needsRemap("ql-strain"))
        XCTAssertEqual(InjuryCatalog.normalizedID("ql-strain"), "patellar-tendinopathy")
        XCTAssertEqual(InjuryCatalog.definition(for: "ql-strain").id, InjuryCatalog.patellarTendinopathy.id)
        XCTAssertTrue(SettingsSeedPolicy.shouldRemapInjury("ql-strain"))
    }

    func testUnknownIdFallsBackToPatellarTendinopathy() {
        let fallback = InjuryCatalog.definition(for: "future-achilles")
        XCTAssertEqual(fallback.id, InjuryCatalog.defaultSelectable.id)
        XCTAssertEqual(InjuryCatalog.normalizedID("not-a-real-injury"), "patellar-tendinopathy")
        XCTAssertFalse(InjuryCatalog.contains("future-achilles"))
    }

    func testSkipDefaultsToPhaseBNoNotificationsKeepsLift() {
        let skipped = OnboardingCompletion.result(
            skipped: true,
            phase: .aFlareDeLoad,
            notificationsEnabled: true,
            primaryLoadID: PrimaryLoadCatalog.legPress.id
        )
        XCTAssertEqual(skipped.phase, .bIsometrics)
        XCTAssertFalse(skipped.notificationsEnabled)
        XCTAssertEqual(skipped.primaryLoadID, PrimaryLoadCatalog.legPress.id)
    }

    func testCompleteKeepsChosenPhaseAndNormalizesLift() {
        let chosen = OnboardingCompletion.result(
            skipped: false,
            phase: .cHeavySlowResistance,
            notificationsEnabled: true,
            primaryLoadID: "spanish-squat"
        )
        XCTAssertEqual(chosen.phase, .cHeavySlowResistance)
        XCTAssertTrue(chosen.notificationsEnabled)
        XCTAssertEqual(chosen.primaryLoadID, PrimaryLoadCatalog.seatedExtension.id)
    }

    func testRetiredQLLiftsRemapToSeatedExtensionThroughOnboarding() {
        for retired in ["ql-hip-thrust", "ql-side-bend", "ql-walk", "hack-squat"] {
            let chosen = OnboardingCompletion.result(
                skipped: false,
                phase: .bIsometrics,
                notificationsEnabled: false,
                primaryLoadID: retired
            )
            XCTAssertEqual(chosen.primaryLoadID, PrimaryLoadCatalog.defaultID, retired)
        }
    }
}
