import XCTest
@testable import R3hab

final class InjuryCatalogTests: XCTestCase {
    func testSelectableIncludesKneeLabelsAndQLStrain() {
        let ids = InjuryCatalog.selectable.map(\.id)
        XCTAssertEqual(ids, [
            "jumpers-knee",
            "patellar-tendinopathy",
            "patellar-tendonitis",
            "ql-strain"
        ])
        XCTAssertEqual(InjuryCatalog.selectable.map(\.title), [
            "Jumper's knee",
            "Patellar tendinopathy",
            "Patellar tendonitis",
            "QL strain"
        ])
        XCTAssertTrue(InjuryCatalog.contains("ql-strain"))
        XCTAssertTrue(InjuryCatalog.qlStrain.isSelectable)
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
            primaryLoadID: PrimaryLoadCatalog.wallSit.id
        )
        XCTAssertEqual(skipped.phase, .bIsometrics)
        XCTAssertFalse(skipped.notificationsEnabled)
        XCTAssertEqual(skipped.injuryID, InjuryCatalog.jumpersKnee.id)
        XCTAssertEqual(skipped.protocolTrack, .knee)
        XCTAssertEqual(skipped.primaryLoadID, PrimaryLoadCatalog.wallSit.id)
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
            primaryLoadID: PrimaryLoadCatalog.spanishSquat.id
        )
        XCTAssertEqual(chosen.phase, .cHeavySlowResistance)
        XCTAssertTrue(chosen.notificationsEnabled)
        XCTAssertEqual(chosen.injuryID, "patellar-tendonitis")
        XCTAssertEqual(chosen.protocolTrack, .knee)
        XCTAssertEqual(chosen.primaryLoadID, PrimaryLoadCatalog.spanishSquat.id)
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
