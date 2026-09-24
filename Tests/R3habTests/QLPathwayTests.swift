import XCTest
@testable import R3habDomain

final class QLPathwayTests: XCTestCase {
    func testQLStrainDoesNotRemapToPatellar() {
        XCTAssertFalse(InjuryCatalog.retiredIDs.contains("ql-strain"))
        XCTAssertFalse(InjuryCatalog.needsRemap("ql-strain"))
        XCTAssertEqual(InjuryCatalog.normalizedID("ql-strain"), "ql-strain")
        XCTAssertEqual(InjuryCatalog.definition(for: "ql-strain").id, InjuryCatalog.qlStrain.id)
        XCTAssertEqual(InjuryCatalog.qlStrain.protocolName, "QL strain")
    }

    func testPatellarAliasesStillRemap() {
        XCTAssertEqual(InjuryCatalog.normalizedID("jumpers-knee"), "patellar-tendinopathy")
        XCTAssertEqual(InjuryCatalog.normalizedID("patellar-tendonitis"), "patellar-tendinopathy")
        XCTAssertTrue(InjuryCatalog.needsRemap("jumpers-knee"))
        XCTAssertFalse(InjuryCatalog.needsRemap("patellar-tendinopathy"))
        XCTAssertEqual(InjuryCatalog.normalizedID("not-a-real-injury"), "patellar-tendinopathy")
    }

    func testQLModalitiesStayLiveAndKneeProfileIgnoresThem() {
        XCTAssertEqual(
            PrimaryLoadCatalog.options(for: InjuryCatalog.qlStrain.id).map(\.id),
            ["ql-walk", "ql-side-bend", "ql-hip-thrust"]
        )
        XCTAssertEqual(
            PrimaryLoadCatalog.options(for: InjuryCatalog.patellarTendinopathy.id).map(\.id),
            ["seated-extension", "leg-press"]
        )
        for live in ["ql-walk", "ql-side-bend", "ql-hip-thrust"] {
            XCTAssertFalse(PrimaryLoadCatalog.needsRemap(live), live)
            XCTAssertEqual(PrimaryLoadCatalog.normalizedID(live), live, live)
            XCTAssertEqual(
                PrimaryLoadCatalog.normalizedID(live, injuryID: InjuryCatalog.qlStrain.id),
                live
            )
            XCTAssertEqual(
                PrimaryLoadCatalog.normalizedID(live, injuryID: InjuryCatalog.patellarTendinopathy.id),
                "seated-extension"
            )
        }
        XCTAssertEqual(PrimaryLoadCatalog.normalizedID("spanish-squat"), "seated-extension")
        XCTAssertEqual(PrimaryLoadCatalog.normalizedID("wall-sit"), "seated-extension")
        XCTAssertTrue(PrimaryLoadCatalog.needsRemap("spanish-squat"))
    }

    func testKneeChipsStayKneeAndQLChipsAreTheThreeModalities() {
        let knee = SessionPreset.forPhase(.cHeavySlowResistance, primaryLoadID: "seated-extension")
        XCTAssertEqual(knee.map(\.id), ["ke", "lp"])
        let ql = SessionPreset.forPhase(.aFlareDeLoad, primaryLoadID: "ql-side-bend")
        XCTAssertEqual(ql.first?.id, "ql-side-bend")
        XCTAssertEqual(Set(ql.map(\.id)), ["ql-walk", "ql-side-bend", "ql-hip-thrust"])
        XCTAssertTrue(SessionPreset.all.first { $0.id == "ql-walk" }?.tracksWalk == true)
        XCTAssertFalse(PrimaryLoadCatalog.qlHipThrust.usesPatellarLadder)
        XCTAssertTrue(PrimaryLoadCatalog.qlSideBend.allowsSideSplit)
        XCTAssertFalse(PrimaryLoadCatalog.qlHipThrust.allowsSideSplit)
    }

    func testWalkAndWeightedSessionValidation() {
        let ok = SessionSaveValidation.validate(
            painDuring: 2,
            painAfter: nil,
            whatIDid: "Walking",
            sets: [ResistanceSet(steps: 4000, durationMinutes: 30)]
        )
        XCTAssertNil(ok)

        let badSteps = SessionSaveValidation.validate(
            painDuring: 1,
            painAfter: nil,
            whatIDid: "Walking",
            sets: [ResistanceSet(steps: 0)]
        )
        XCTAssertEqual(badSteps, .nonPositiveSteps)

        let badMinutes = SessionSaveValidation.validate(
            painDuring: 1,
            painAfter: nil,
            whatIDid: "Hip thrust",
            sets: [ResistanceSet(reps: 8, loadLbs: 45, durationMinutes: 0)]
        )
        XCTAssertEqual(badMinutes, .nonPositiveDuration)

        let legacy = try? JSONDecoder().decode(
            [ResistanceSet].self,
            from: Data(#"[{"id":"11111111-1111-1111-1111-111111111111","reps":8,"loadLbs":35,"isWarmup":false}]"#.utf8)
        )
        XCTAssertEqual(legacy?.first?.reps, 8)
        XCTAssertNil(legacy?.first?.steps)
    }

    func testQLStubPrefillsLastLoadAndDoesNotAdviseALadder() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let session = TrainingSessionSnapshot(
            date: now,
            createdAt: now,
            sessionType: .other,
            response24h: .same,
            decision: nil,
            resolvedAt: nil,
            snoozedUntil: nil,
            phase: .bIsometrics,
            painDuring: 1,
            whatIDid: "Hip thrust",
            resistanceSets: [ResistanceSet(reps: 10, loadLbs: 95, isWarmup: false)]
        )
        let prefill = QLLoggingStub.lastWeighted(sessions: [session], title: "Hip thrust")
        XCTAssertEqual(prefill?.loadLbs, 95)
        XCTAssertEqual(prefill?.reps, 10)
        XCTAssertNil(QLLoggingStub.lastWeighted(sessions: [], title: "Side bend"))
        XCTAssertTrue(QLLoggingStub.stepTargetLine(stepNearNormalMin: 6000).contains("6000"))
        XCTAssertTrue(QLLoggingStub.stepTargetLine(stepNearNormalMin: 6000).contains("TBD"))

        let ladder = ProgressionEngine.today(
            sessions: [session],
            primaryLoadTitle: "Hip thrust",
            asOf: now
        )
        XCTAssertEqual(ladder.reason, ProgressionEngine.reasonStart)
        XCTAssertNotEqual(ladder.stance, .advance)
    }
}
