import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class ProgressionEngineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var day0: Date {
        calendar.startOfDay(for: Date(timeIntervalSince1970: 1_777_766_400))
    }

    func testEmptyHistoryHoldsDefaultThreeByEight() {
        let result = ProgressionEngine.today(
            sessions: [],
            checkIns: [],
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: nil))
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.blockedBy, [])
    }

    func testLadderAdvancesAfterTwoCleanHits() {
        let first = hsr(dayOffset: -4, sets: 3, reps: 8, load: 35, pain: 2)
        let second = hsr(dayOffset: -2, sets: 3, reps: 8, load: 35, pain: 1)
        let checkIns = morningPair(for: [first, second], am: 2)
        let result = ProgressionEngine.today(
            sessions: [first, second],
            checkIns: checkIns,
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 10, loadLbs: 35))
        XCTAssertEqual(result.stance, .advance)
        XCTAssertEqual(result.blockedBy, [])
    }

    func testLadderWalksToLoadBump() {
        var current = LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35)
        current = ProgressionEngine.advanced(from: current)
        XCTAssertEqual(current, LoadPrescription(workingSets: 3, reps: 10, loadLbs: 35))
        current = ProgressionEngine.advanced(from: current)
        XCTAssertEqual(current, LoadPrescription(workingSets: 3, reps: 12, loadLbs: 35))
        current = ProgressionEngine.advanced(from: current)
        XCTAssertEqual(current, LoadPrescription(workingSets: 4, reps: 8, loadLbs: 35))
        current = ProgressionEngine.advanced(from: current)
        XCTAssertEqual(current, LoadPrescription(workingSets: 4, reps: 10, loadLbs: 35))
        current = ProgressionEngine.advanced(from: current)
        XCTAssertEqual(current, LoadPrescription(workingSets: 4, reps: 12, loadLbs: 35))
        current = ProgressionEngine.advanced(from: current)
        XCTAssertEqual(current, LoadPrescription(workingSets: 4, reps: 8, loadLbs: 40))
    }

    func testDropStepsBackOneRungThenDropsLoadAtFloor() {
        XCTAssertEqual(
            ProgressionEngine.dropped(from: LoadPrescription(workingSets: 4, reps: 8, loadLbs: 35)),
            LoadPrescription(workingSets: 3, reps: 12, loadLbs: 35)
        )
        XCTAssertEqual(
            ProgressionEngine.dropped(from: LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35)),
            LoadPrescription(workingSets: 3, reps: 8, loadLbs: 30)
        )
    }

    func testOneCleanHitHolds() {
        let only = hsr(dayOffset: -2, sets: 3, reps: 8, load: 35, pain: 2)
        let result = ProgressionEngine.today(
            sessions: [only],
            checkIns: morningPair(for: [only], am: 2),
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35))
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.blockedBy, [.consecutiveTopReps])
    }

    func testMissedRepsHoldAndBlockConsecutiveGate() {
        let first = hsr(dayOffset: -4, sets: 3, reps: 8, load: 35, pain: 2)
        let miss = hsr(dayOffset: -2, sets: 3, reps: 6, load: 35, pain: 2)
        let result = ProgressionEngine.today(
            sessions: [first, miss],
            checkIns: morningPair(for: [first, miss], am: 2),
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35))
        XCTAssertEqual(result.stance, .hold)
        XCTAssertTrue(result.blockedBy.contains(.consecutiveTopReps))
        XCTAssertFalse(result.blockedBy.contains(.painDuring))
    }

    func testPainDuringFiveStillAllowsAdvance() {
        let first = hsr(dayOffset: -4, sets: 3, reps: 8, load: 35, pain: 5)
        let second = hsr(dayOffset: -2, sets: 3, reps: 8, load: 35, pain: 5)
        let result = ProgressionEngine.today(
            sessions: [first, second],
            checkIns: morningPair(for: [first, second], am: 2),
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.stance, .advance)
        XCTAssertFalse(result.blockedBy.contains(.painDuring))
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 10, loadLbs: 35))
    }

    func testPainDuringAboveFiveDropsOneStep() {
        let first = hsr(dayOffset: -4, sets: 3, reps: 10, load: 35, pain: 2)
        let hot = hsr(dayOffset: -2, sets: 3, reps: 10, load: 35, pain: 6)
        let result = ProgressionEngine.today(
            sessions: [first, hot],
            checkIns: morningPair(for: [first, hot], am: 2),
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35))
        XCTAssertEqual(result.stance, .drop)
        XCTAssertTrue(result.blockedBy.contains(.painDuring))
    }

    func testPerSetPainCanFailThePainGate() {
        var hot = hsr(dayOffset: -2, sets: 3, reps: 8, load: 35, pain: 2)
        hot.resistanceSets = SessionPrefill.workSets(
            from: LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35),
            laterality: .bilateral
        )
        hot.resistanceSets[0].painDuring = 7
        let result = ProgressionEngine.today(
            sessions: [hot],
            checkIns: morningPair(for: [hot], am: 2),
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.stance, .drop)
        XCTAssertTrue(result.blockedBy.contains(.painDuring))
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 30))
    }

    func testNextMorningAboveBaselineDrops() {
        let first = hsr(dayOffset: -4, sets: 3, reps: 8, load: 35, pain: 2)
        let second = hsr(dayOffset: -2, sets: 3, reps: 8, load: 35, pain: 2)
        var checkIns = morningPair(for: [first, second], am: 2)
        if let index = checkIns.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day(-1)) }) {
            checkIns[index].restingPainAM = 4
        }
        let result = ProgressionEngine.today(
            sessions: [first, second],
            checkIns: checkIns,
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.stance, .drop)
        XCTAssertTrue(result.blockedBy.contains(.nextMorningBaseline))
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 30))
    }

    func testUnknownNextMorningBlocksAdvanceWithoutDrop() {
        let first = hsr(dayOffset: -3, sets: 3, reps: 8, load: 35, pain: 2)
        let second = hsr(dayOffset: 0, sets: 3, reps: 8, load: 35, pain: 2)
        let result = ProgressionEngine.today(
            sessions: [first, second],
            checkIns: [
                DailyCheckInSnapshot(date: day(-3), restingPainAM: 2),
                DailyCheckInSnapshot(date: day(-2), restingPainAM: 2)
            ],
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.stance, .hold)
        XCTAssertTrue(result.blockedBy.contains(.nextMorningBaseline))
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35))
    }

    func testWeekOverWeekCreepDrops() {
        let first = hsr(dayOffset: -4, sets: 3, reps: 8, load: 35, pain: 2)
        let second = hsr(dayOffset: -2, sets: 3, reps: 8, load: 35, pain: 2)
        var checkIns = morningPair(for: [first, second], am: 2)
        checkIns.append(contentsOf: [
            DailyCheckInSnapshot(date: day(-13), restingPainAM: 1),
            DailyCheckInSnapshot(date: day(-12), restingPainAM: 1),
            DailyCheckInSnapshot(date: day(-6), restingPainAM: 3),
            DailyCheckInSnapshot(date: day(-5), restingPainAM: 3)
        ])
        let result = ProgressionEngine.today(
            sessions: [first, second],
            checkIns: checkIns,
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.stance, .drop)
        XCTAssertTrue(result.blockedBy.contains(.weekOverWeekCreep))
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 30))
    }

    func testUserHistoryClimbsTowardThreeByTenAt35() {
        let sessions = [
            hsr(dayOffset: -5, sets: 3, reps: 8, load: 35, pain: 2, unilateral: true),
            hsr(dayOffset: -3, sets: 3, reps: 8, load: 35, pain: 1, unilateral: true)
        ]
        let result = ProgressionEngine.today(
            sessions: sessions,
            checkIns: morningPair(for: sessions, am: 2),
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.target.displayLine, "3×10 @ 35 lbs")
        XCTAssertEqual(result.target.todayLine, "Today: 3×10 @ 35 lbs")
        XCTAssertEqual(result.stance, .advance)
        XCTAssertEqual(result.laterality, .bilateral)
    }

    func testUnilateralSixRowsCountAsThreeSets() {
        let session = hsr(dayOffset: -2, sets: 3, reps: 8, load: 35, pain: 2, unilateral: true)
        XCTAssertEqual(session.resistanceSets.count, 6)
        XCTAssertEqual(
            ProgressionEngine.inferPrescription(session),
            LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35)
        )
    }

    func testPrefillBuildsEditableWorkingPairs() {
        let target = LoadPrescription(workingSets: 3, reps: 10, loadLbs: 35)
        let sets = SessionPrefill.workSets(from: target, laterality: .bilateral)
        XCTAssertEqual(sets.count, 6)
        XCTAssertTrue(sets.allSatisfy { $0.reps == 10 })
        XCTAssertTrue(sets.allSatisfy { $0.loadLbs == 35 })
        XCTAssertTrue(sets.allSatisfy { $0.painDuring == nil })
        XCTAssertEqual(SessionSummary.groupWorkSets(sets).count, 3)
    }

    func testSaveCopiesSessionPainOntoSetsWithoutPain() {
        let seeded = SessionPrefill.workSets(
            from: LoadPrescription(workingSets: 3, reps: 10, loadLbs: 35),
            laterality: .bilateral
        )
        var seededWithOne = seeded
        seededWithOne[0].painDuring = 4
        let saved = ProgressionEngine.applySessionPain(2, to: seededWithOne)
        XCTAssertEqual(saved[0].painDuring, 4)
        XCTAssertTrue(saved.dropFirst().allSatisfy { $0.painDuring == 2 })
    }

    func testLegacyResistanceSetJSONDecodesWithoutPain() throws {
        let json = """
        [{"id":"00000000-0000-0000-0000-000000000001","reps":8,"loadLbs":35,"isWarmup":false,"side":"left"}]
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode([ResistanceSet].self, from: data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].reps, 8)
        XCTAssertEqual(decoded[0].loadLbs, 35)
        XCTAssertNil(decoded[0].painDuring)
    }

    func testIgnoresIsometricAndDraftSessions() {
        let iso = session(
            dayOffset: -2,
            type: .isometrics,
            sets: 3,
            reps: 8,
            load: 20,
            pain: 1
        )
        let draft = hsr(dayOffset: -1, sets: 4, reps: 12, load: 40, pain: 1)
        var draftCopy = draft
        draftCopy.isDraft = true
        let live = hsr(dayOffset: -3, sets: 3, reps: 8, load: 35, pain: 2)
        let result = ProgressionEngine.today(
            sessions: [iso, draftCopy, live],
            checkIns: morningPair(for: [live], am: 2),
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35))
        XCTAssertEqual(result.stance, .hold)
    }

    func testEvaluateAfterSaveAdvancesWhenTheNewSessionCompletesThePair() {
        let first = hsr(dayOffset: -3, sets: 3, reps: 8, load: 35, pain: 2)
        let second = hsr(dayOffset: -1, sets: 3, reps: 8, load: 35, pain: 2)
        let after = ProgressionEngine.evaluateAfterSave(
            sessions: [first, second],
            checkIns: morningPair(for: [first, second], am: 2),
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(after.stance, .advance)
        XCTAssertEqual(after.target, LoadPrescription(workingSets: 3, reps: 10, loadLbs: 35))
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: day0)!
    }

    private func hsr(
        dayOffset: Int,
        sets: Int,
        reps: Int,
        load: Double,
        pain: Int,
        unilateral: Bool = false
    ) -> TrainingSessionSnapshot {
        session(
            dayOffset: dayOffset,
            type: .hsrStrength,
            sets: sets,
            reps: reps,
            load: load,
            pain: pain,
            unilateral: unilateral
        )
    }

    private func session(
        dayOffset: Int,
        type: SessionType,
        sets: Int,
        reps: Int,
        load: Double,
        pain: Int,
        unilateral: Bool = false
    ) -> TrainingSessionSnapshot {
        let date = day(dayOffset)
        let target = LoadPrescription(workingSets: sets, reps: reps, loadLbs: load)
        var rows = SessionPrefill.workSets(from: target, laterality: .bilateral)
        if unilateral {
            for index in rows.indices where rows[index].side == .right {
                rows[index].loadLbs = load
            }
        }
        return TrainingSessionSnapshot(
            date: date,
            createdAt: date.addingTimeInterval(60),
            sessionType: type,
            response24h: .same,
            decision: .stay,
            resolvedAt: date.addingTimeInterval(86_400),
            snoozedUntil: nil,
            phase: .cHeavySlowResistance,
            painDuring: pain,
            painAfter: pain,
            whatIDid: "Seated extension · \(sets)×\(reps) @ \(LoadCopy.labeled(load))",
            resistanceSets: rows
        )
    }

    private func morningPair(for sessions: [TrainingSessionSnapshot], am: Int) -> [DailyCheckInSnapshot] {
        var rows: [DailyCheckInSnapshot] = []
        for session in sessions {
            let start = calendar.startOfDay(for: session.date)
            rows.append(DailyCheckInSnapshot(date: start, restingPainAM: am))
            if let next = calendar.date(byAdding: .day, value: 1, to: start) {
                rows.append(DailyCheckInSnapshot(date: next, restingPainAM: am))
            }
        }
        return rows
    }
}
