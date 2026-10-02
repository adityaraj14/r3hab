import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class TodaySessionEntryTests: XCTestCase {
    private let threeByEight = LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35)

    func testRestDayCardHidesLoadProgression() {
        XCTAssertFalse(TodayNextAction.restDay.showsLoadProgression)
        XCTAssertTrue(TodayNextAction.logSession.showsLoadProgression)
        XCTAssertTrue(TodayNextAction.logMorning.showsLoadProgression)
        XCTAssertTrue(TodayNextAction.logEvening.showsLoadProgression)
        XCTAssertTrue(TodayNextAction.allDone.showsLoadProgression)
        let id = UUID()
        XCTAssertTrue(TodayNextAction.resolvePending(sessionID: id, remaining: 0).showsLoadProgression)
        XCTAssertTrue(TodayNextAction.logAfterPain(sessionID: id).showsLoadProgression)
    }

    func testRestDayOmitsProgressionTarget() {
        let entry = TodaySessionEntry.resolve(
            isRestDay: true,
            hasDraft: false,
            todaySessions: [],
            target: threeByEight,
            laterality: .bilateral
        )
        XCTAssertEqual(entry, .rest)
        XCTAssertNil(entry.load)
    }

    func testRestDayDraftResumesWithoutLoad() {
        let entry = TodaySessionEntry.resolve(
            isRestDay: true,
            hasDraft: true,
            todaySessions: [],
            target: threeByEight,
            laterality: .bilateral
        )
        XCTAssertEqual(entry, .resumeDraft)
        XCTAssertNil(entry.load)
    }

    func testTrainingDayListsEachWorkingSet() {
        let entry = TodaySessionEntry.resolve(
            isRestDay: false,
            hasDraft: false,
            todaySessions: [],
            target: threeByEight,
            laterality: .bilateral
        )
        XCTAssertEqual(
            entry,
            .target(
                TodaySessionLoad(
                    warmupNote: "Warm-up 2×30s @ 35 lb",
                    workLines: ["8 @ 35 lb", "8 @ 35 lb", "8 @ 35 lb"]
                )
            )
        )
    }

    func testLoggedSessionListsWorkSetsAndKeepsStatus() {
        let sets = SessionPrefill.workSets(from: threeByEight, laterality: .bilateral)
            + [SessionPrefill.warmupSet(loadLbs: 35)]
        let session = TrainingSessionSnapshot(
            date: Date(timeIntervalSince1970: 0),
            createdAt: Date(timeIntervalSince1970: 60),
            sessionType: .hsrStrength,
            response24h: .pending,
            decision: nil,
            resolvedAt: nil,
            snoozedUntil: nil,
            phase: .cHeavySlowResistance,
            painDuring: 2,
            resistanceSets: sets
        )
        let entry = TodaySessionEntry.resolve(
            isRestDay: false,
            hasDraft: false,
            todaySessions: [session],
            target: threeByEight,
            laterality: .bilateral
        )
        XCTAssertEqual(
            entry,
            .logged(
                TodaySessionLoad(
                    warmupNote: "Warm-up 2×30s @ 35 lb",
                    workLines: ["8 @ 35 lb", "8 @ 35 lb", "8 @ 35 lb"]
                ),
                status: "Pain during 2. Pain after is not recorded."
            )
        )
    }

    func testLoggedRestDayKeepsSetsNotRestAffordance() {
        let sets = SessionPrefill.workSets(from: threeByEight, laterality: .bilateral)
        let session = TrainingSessionSnapshot(
            date: Date(timeIntervalSince1970: 0),
            createdAt: Date(timeIntervalSince1970: 60),
            sessionType: .hsrStrength,
            response24h: .same,
            decision: .stay,
            resolvedAt: Date(timeIntervalSince1970: 86_400),
            snoozedUntil: nil,
            phase: .cHeavySlowResistance,
            painDuring: 1,
            painAfter: 1,
            resistanceSets: sets
        )
        let entry = TodaySessionEntry.resolve(
            isRestDay: true,
            hasDraft: false,
            todaySessions: [session],
            target: threeByEight,
            laterality: .bilateral
        )
        XCTAssertEqual(
            entry,
            .logged(
                TodaySessionLoad(
                    warmupNote: nil,
                    workLines: ["8 @ 35 lb", "8 @ 35 lb", "8 @ 35 lb"]
                ),
                status: "Recorded"
            )
        )
    }
}
