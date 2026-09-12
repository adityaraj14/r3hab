import XCTest
@testable import R3hab

final class InjuryCatalogTests: XCTestCase {
    func testSelectableIsCollapsedKneePlusQL() {
        let ids = InjuryCatalog.selectable.map(\.id)
        XCTAssertEqual(ids, [
            "patellar-tendinopathy",
            "ql-strain"
        ])
        XCTAssertEqual(InjuryCatalog.selectable.map(\.title), [
            "Jumper’s knee / patellar tendinopathy",
            "QL strain"
        ])
        XCTAssertEqual(InjuryCatalog.selectable.count, 2)
        XCTAssertTrue(InjuryCatalog.contains("ql-strain"))
        XCTAssertTrue(InjuryCatalog.qlStrain.isSelectable)
        XCTAssertFalse(InjuryCatalog.jumpersKnee.isSelectable)
        XCTAssertFalse(InjuryCatalog.patellarTendonitis.isSelectable)
    }

    func testCollapsedKneeAliasesRemapToPatellarTendinopathy() {
        XCTAssertEqual(InjuryCatalog.normalizedID("jumpers-knee"), "patellar-tendinopathy")
        XCTAssertEqual(InjuryCatalog.normalizedID("patellar-tendonitis"), "patellar-tendinopathy")
        XCTAssertEqual(InjuryCatalog.definition(for: "jumpers-knee").id, "patellar-tendinopathy")
        XCTAssertTrue(InjuryCatalog.needsRemap("jumpers-knee"))
        XCTAssertTrue(InjuryCatalog.needsRemap("patellar-tendonitis"))
        XCTAssertFalse(InjuryCatalog.needsRemap("patellar-tendinopathy"))
        XCTAssertFalse(InjuryCatalog.needsRemap("ql-strain"))
    }

    func testKneeLabelsMapToKneeAndQLMapsToQLTrack() {
        XCTAssertEqual(InjuryCatalog.jumpersKnee.protocolTrack, .knee)
        XCTAssertEqual(InjuryCatalog.patellarTendinopathy.protocolTrack, .knee)
        XCTAssertEqual(InjuryCatalog.patellarTendonitis.protocolTrack, .knee)
        XCTAssertEqual(InjuryCatalog.qlStrain.protocolTrack, .ql)
        XCTAssertEqual(InjuryCatalog.definition(for: "ql-strain").protocolTrack, .ql)
    }

    func testUnknownIdFallsBackToPatellarTendinopathy() {
        let fallback = InjuryCatalog.definition(for: "future-achilles")
        XCTAssertEqual(fallback.id, InjuryCatalog.defaultSelectable.id)
        XCTAssertEqual(InjuryCatalog.normalizedID("not-a-real-injury"), "patellar-tendinopathy")
        XCTAssertFalse(InjuryCatalog.contains("future-achilles"))
    }

    func testPage0SkipKeepsKneeDefault() {
        let skipped = OnboardingCompletion.result(
            skipped: true,
            phase: .aFlareDeLoad,
            notificationsEnabled: true,
            injuryID: InjuryCatalog.defaultSelectable.id,
            primaryLoadID: PrimaryLoadCatalog.defaultID
        )
        XCTAssertEqual(skipped.phase, .bIsometrics)
        XCTAssertFalse(skipped.notificationsEnabled)
        XCTAssertEqual(skipped.injuryID, InjuryCatalog.defaultSelectable.id)
        XCTAssertEqual(skipped.protocolTrack, .knee)
        XCTAssertEqual(skipped.primaryLoadID, PrimaryLoadCatalog.defaultID)
    }

    func testSkipKeepsChosenKneeInjuryAndLoad() {
        let skipped = OnboardingCompletion.result(
            skipped: true,
            phase: .aFlareDeLoad,
            notificationsEnabled: true,
            injuryID: InjuryCatalog.jumpersKnee.id,
            primaryLoadID: PrimaryLoadCatalog.legPress.id
        )
        XCTAssertEqual(skipped.phase, .bIsometrics)
        XCTAssertFalse(skipped.notificationsEnabled)
        XCTAssertEqual(skipped.injuryID, InjuryCatalog.patellarTendinopathy.id)
        XCTAssertEqual(skipped.protocolTrack, .knee)
        XCTAssertEqual(skipped.primaryLoadID, PrimaryLoadCatalog.legPress.id)
    }

    func testSkipKeepsChosenQLAndRemapsKneeLoad() {
        let skipped = OnboardingCompletion.result(
            skipped: true,
            phase: .cHeavySlowResistance,
            notificationsEnabled: true,
            injuryID: InjuryCatalog.qlStrain.id,
            primaryLoadID: PrimaryLoadCatalog.seatedExtension.id
        )
        XCTAssertEqual(skipped.phase, .bIsometrics)
        XCTAssertFalse(skipped.notificationsEnabled)
        XCTAssertEqual(skipped.injuryID, "ql-strain")
        XCTAssertEqual(skipped.protocolTrack, .ql)
        XCTAssertEqual(skipped.primaryLoadID, PrimaryLoadCatalog.hipThrust.id)
    }

    func testCompleteKeepsChosenInjuryAndPhase() {
        let chosen = OnboardingCompletion.result(
            skipped: false,
            phase: .cHeavySlowResistance,
            notificationsEnabled: true,
            injuryID: InjuryCatalog.patellarTendonitis.id,
            primaryLoadID: "spanish-squat"
        )
        XCTAssertEqual(chosen.phase, .cHeavySlowResistance)
        XCTAssertTrue(chosen.notificationsEnabled)
        XCTAssertEqual(chosen.injuryID, InjuryCatalog.patellarTendinopathy.id)
        XCTAssertEqual(chosen.protocolTrack, .knee)
        XCTAssertEqual(chosen.primaryLoadID, PrimaryLoadCatalog.seatedExtension.id)
    }

    func testCompleteQLKeepsHipThrustDefault() {
        let chosen = OnboardingCompletion.result(
            skipped: false,
            phase: .bIsometrics,
            notificationsEnabled: false,
            injuryID: InjuryCatalog.qlStrain.id,
            primaryLoadID: PrimaryLoadCatalog.hipThrust.id
        )
        XCTAssertEqual(chosen.injuryID, "ql-strain")
        XCTAssertEqual(chosen.protocolTrack, .ql)
        XCTAssertEqual(chosen.primaryLoadID, "ql-hip-thrust")
    }

    func testCompleteNormalizesUnknownPrimaryLoadToSeatedExtension() {
        let chosen = OnboardingCompletion.result(
            skipped: false,
            phase: .bIsometrics,
            notificationsEnabled: false,
            injuryID: InjuryCatalog.defaultSelectable.id,
            primaryLoadID: "hack-squat"
        )
        XCTAssertEqual(chosen.primaryLoadID, PrimaryLoadCatalog.defaultID)
    }
}
