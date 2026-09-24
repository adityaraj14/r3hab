import XCTest
@testable import R3hab

final class InjuryCatalogTests: XCTestCase {
    func testCatalogShipsKneeAndQL() {
        XCTAssertEqual(InjuryCatalog.all.map(\.id), ["patellar-tendinopathy", "ql-strain"])
        XCTAssertEqual(
            InjuryCatalog.defaultSelectable.title,
            "Jumper’s knee / patellar tendinopathy / patellar tendonitis"
        )
        XCTAssertTrue(InjuryCatalog.contains("patellar-tendinopathy"))
        XCTAssertTrue(InjuryCatalog.contains("ql-strain"))
        XCTAssertEqual(InjuryCatalog.qlStrain.protocolName, "QL strain")
        XCTAssertNotEqual(InjuryCatalog.qlStrain.protocolName, InjuryCatalog.patellarTendinopathy.protocolName)
    }

    func testKneeAliasesRemapToPatellarTendinopathy() {
        XCTAssertEqual(InjuryCatalog.normalizedID("jumpers-knee"), "patellar-tendinopathy")
        XCTAssertEqual(InjuryCatalog.normalizedID("patellar-tendonitis"), "patellar-tendinopathy")
        XCTAssertEqual(InjuryCatalog.definition(for: "jumpers-knee").id, "patellar-tendinopathy")
        XCTAssertTrue(InjuryCatalog.needsRemap("jumpers-knee"))
        XCTAssertTrue(InjuryCatalog.needsRemap("patellar-tendonitis"))
        XCTAssertFalse(InjuryCatalog.needsRemap("patellar-tendinopathy"))
    }

    func testQLStrainStaysSelectable() {
        XCTAssertFalse(InjuryCatalog.retiredIDs.contains("ql-strain"))
        XCTAssertFalse(InjuryCatalog.needsRemap("ql-strain"))
        XCTAssertEqual(InjuryCatalog.normalizedID("ql-strain"), "ql-strain")
        XCTAssertEqual(InjuryCatalog.definition(for: "ql-strain").id, InjuryCatalog.qlStrain.id)
        XCTAssertFalse(SettingsSeedPolicy.shouldRemapInjury("ql-strain"))
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

    func testPatellarOnboardingStillDropsQLModalities() {
        for retired in ["ql-hip-thrust", "ql-side-bend", "ql-walk", "hack-squat"] {
            let chosen = OnboardingCompletion.result(
                skipped: false,
                phase: .bIsometrics,
                notificationsEnabled: false,
                injuryID: InjuryCatalog.patellarTendinopathy.id,
                primaryLoadID: retired
            )
            XCTAssertEqual(chosen.primaryLoadID, PrimaryLoadCatalog.defaultID, retired)
            XCTAssertEqual(chosen.injuryID, InjuryCatalog.patellarTendinopathy.id)
        }
    }

    func testQLOnboardingKeepsWalkSideBendAndHipThrust() {
        let chosen = OnboardingCompletion.result(
            skipped: false,
            phase: .bIsometrics,
            notificationsEnabled: false,
            injuryID: "ql-strain",
            primaryLoadID: "ql-side-bend"
        )
        XCTAssertEqual(chosen.injuryID, "ql-strain")
        XCTAssertEqual(chosen.primaryLoadID, "ql-side-bend")
        let skipped = OnboardingCompletion.result(
            skipped: true,
            phase: .cHeavySlowResistance,
            notificationsEnabled: true,
            injuryID: InjuryCatalog.qlStrain.id,
            primaryLoadID: PrimaryLoadCatalog.qlWalk.id
        )
        XCTAssertEqual(skipped.phase, .bIsometrics)
        XCTAssertEqual(skipped.injuryID, InjuryCatalog.qlStrain.id)
        XCTAssertEqual(skipped.primaryLoadID, PrimaryLoadCatalog.qlWalk.id)
    }
}
