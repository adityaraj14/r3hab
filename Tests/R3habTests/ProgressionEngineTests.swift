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

    func testEmptyHistoryInWeekOneAsksForALoadOnTheHold() {
        let result = ProgressionEngine.today(
            sessions: [],
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.target.workingSets, 5)
        XCTAssertEqual(result.target.holdSeconds, 45)
        XCTAssertNil(result.target.loadLbs)
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.reason, ProgressionEngine.reasonStart)
        XCTAssertNil(result.pendingResolveID)
        XCTAssertNil(result.painWarning)
    }

    func testWeekThreeEmptyHistoryUsesFourByFifteen() {
        let result = advise(sessions: [], week: 3)
        XCTAssertEqual(result.target.workingSets, 4)
        XCTAssertEqual(result.target.reps, 15)
        XCTAssertNil(result.target.loadLbs)
        XCTAssertEqual(result.target.tempo, "3 seconds up, 3 seconds down")
        XCTAssertEqual(result.reason, TwelveWeekPlan.reasonPickLoad)
    }

    func testNextMorningAboveBaselineDropsFivePoundsForOneSession() {
        let logged = hsr(dayOffset: -2, sets: 4, reps: 15, load: 40, pain: 2)
        let result = advise(
            sessions: [logged],
            week: 3,
            checkIns: [
                checkIn(dayOffset: -2, am: 1),
                checkIn(dayOffset: -1, am: 3)
            ]
        )
        XCTAssertEqual(result.stance, .drop)
        XCTAssertEqual(result.target.loadLbs, 35)
        XCTAssertEqual(result.target.reps, 15)
        XCTAssertEqual(result.reason, TwelveWeekPlan.reasonDropOneSession)
        XCTAssertEqual(result.suggestedChangeLoadLbs, 35)
    }

    func testPainAboveThreeWarnsAndDoesNotDropWhenTheMorningIsQuiet() {
        let logged = hsr(dayOffset: -2, sets: 4, reps: 15, load: 40, pain: 4)
        let result = advise(
            sessions: [logged],
            week: 3,
            checkIns: [
                checkIn(dayOffset: -2, am: 1),
                checkIn(dayOffset: -1, am: 1)
            ]
        )
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.target.loadLbs, 40)
        XCTAssertEqual(result.reason, TwelveWeekPlan.reasonPainHeld)
        XCTAssertNotNil(result.painWarning)
        XCTAssertTrue(result.blockedBy.contains(.painDuring))
    }

    func testMissingMorningHoldsTheLoad() {
        let logged = hsr(dayOffset: -2, sets: 4, reps: 15, load: 40, pain: 2, response: .pending)
        let result = advise(sessions: [logged], week: 3)
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.target.loadLbs, 40)
        XCTAssertEqual(result.reason, ProgressionEngine.reasonAwaitMorning)
        XCTAssertEqual(result.pendingResolveID, logged.id)
        XCTAssertTrue(result.blockedBy.contains(.awaiting24h))
    }

    func testNewWeekAddsFivePoundsAndUsesThatWeeksReps() {
        let logged = hsr(dayOffset: -7, sets: 4, reps: 15, load: 40, pain: 2)
        let result = advise(
            sessions: [logged],
            week: 4,
            checkIns: [
                checkIn(dayOffset: -7, am: 1),
                checkIn(dayOffset: -6, am: 1)
            ]
        )
        XCTAssertEqual(result.stance, .advance)
        XCTAssertEqual(result.target.loadLbs, 45)
        XCTAssertEqual(result.target.reps, 13)
        XCTAssertEqual(result.reason, TwelveWeekPlan.reasonWeeklyIncrease)
        XCTAssertEqual(result.cardReason, "Increase the load. Try 45 lb.")
    }

    func testWeeksOneAndTwoDoNotAddWeight() {
        let logged = session(
            dayOffset: -2,
            type: .hsrStrength,
            sets: 3,
            reps: 15,
            load: 30,
            pain: 1,
            whatIDid: "Single-leg leg press"
        )
        let result = ProgressionEngine.today(
            sessions: [logged],
            primaryLoadTitle: "Single-leg leg press",
            asOf: day0,
            calendar: calendar,
            programStart: TwelveWeekPlan.startDate(landingTodayInWeek: 2, today: day0, calendar: calendar),
            checkIns: [
                checkIn(dayOffset: -2, am: 0),
                checkIn(dayOffset: -1, am: 0)
            ],
            exercise: .singleLegPress
        )
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.target.loadLbs, 30)
        XCTAssertEqual(result.target.reps, 15)
        XCTAssertEqual(result.target.workingSets, 3)
    }

    func testOneSessionDeloadRestoresThePreviousLoad() {
        // Today is the last day of week 3, so the lighter session is still this week.
        let start = day(-20)
        let heavy = hsr(dayOffset: -8, sets: 4, reps: 15, load: 50, pain: 2)
        let light = hsr(dayOffset: -1, sets: 4, reps: 15, load: 45, pain: 2)
        let result = ProgressionEngine.today(
            sessions: [heavy, light],
            asOf: day0,
            calendar: calendar,
            programStart: start,
            checkIns: [
                checkIn(dayOffset: -8, am: 1),
                checkIn(dayOffset: -7, am: 4),
                checkIn(dayOffset: -1, am: 1),
                checkIn(dayOffset: 0, am: 1)
            ],
            exercise: .legExtension
        )
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.target.loadLbs, 50)
        XCTAssertEqual(result.reason, TwelveWeekPlan.reasonRestored)
    }

    func testShortRepsAreRememberedAgainstThisWeeksTarget() {
        let logged = hsr(dayOffset: -1, sets: 4, reps: 10, load: 40, pain: 1)
        let result = ProgressionEngine.today(
            sessions: [logged],
            asOf: day0,
            calendar: calendar,
            programStart: day(-20),
            checkIns: [
                checkIn(dayOffset: -1, am: 1),
                checkIn(dayOffset: 0, am: 1)
            ],
            exercise: .legExtension
        )
        XCTAssertEqual(result.target.reps, 15)
        XCTAssertEqual(result.lastLoggedReps, 10)
        XCTAssertEqual(result.target.loadLbs, 40)
        XCTAssertEqual(result.stance, .hold)
    }

    func testLegacyShortNameStillCountsAsSeatedLegExtension() {
        var legacy = hsr(dayOffset: -1, sets: 4, reps: 15, load: 35, pain: 2)
        legacy.whatIDid = "\(PrimaryLoadCatalog.legacySeatedExtensionDisplayName) · 4×15 @ 35 lb"
        let result = ProgressionEngine.today(
            sessions: [legacy],
            asOf: day0,
            calendar: calendar,
            programStart: day(-20),
            checkIns: [
                checkIn(dayOffset: -1, am: 1),
                checkIn(dayOffset: 0, am: 1)
            ],
            exercise: .legExtension
        )
        XCTAssertEqual(result.target.loadLbs, 35)
        XCTAssertTrue(ProgressionEngine.matchesPrimaryLoad(legacy, title: PrimaryLoadCatalog.seatedExtension.title))
    }

    func testModalLoadTieGoesToTheLaterSet() {
        var logged = hsr(dayOffset: -2, sets: 4, reps: 15, load: 65, pain: 1)
        logged.resistanceSets = [(15, 65.0), (12, 60.0), (12, 60.0), (12, 60.0)].flatMap {
            SessionSummary.makePair(reps: $0.0, loadLbs: $0.1, holdSeconds: nil, isWarmup: false)
        }
        XCTAssertEqual(ProgressionEngine.inferPrescription(logged)?.loadLbs, 60)
        XCTAssertEqual(ProgressionEngine.inferPrescription(logged)?.reps, 12)
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
        let decoded = try JSONDecoder().decode([ResistanceSet].self, from: Data(json.utf8))
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].reps, 8)
        XCTAssertEqual(decoded[0].loadLbs, 35)
        XCTAssertNil(decoded[0].painDuring)
    }

    func testHipThrustIsOutsideTheKneePlan() {
        let now = day0
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
        let result = ProgressionEngine.today(
            sessions: [session],
            primaryLoadTitle: "Hip thrust",
            asOf: now,
            calendar: calendar
        )
        XCTAssertEqual(result.reason, ProgressionEngine.reasonOutsidePlan)
        XCTAssertEqual(result.stance, .hold)
    }

    private func advise(
        sessions: [TrainingSessionSnapshot],
        week: Int,
        checkIns: [DailyCheckInSnapshot] = []
    ) -> ProgressionResult {
        ProgressionEngine.today(
            sessions: sessions,
            primaryLoadTitle: PrimaryLoadCatalog.seatedExtension.title,
            asOf: day0,
            calendar: calendar,
            programStart: TwelveWeekPlan.startDate(landingTodayInWeek: week, today: day0, calendar: calendar),
            checkIns: checkIns,
            exercise: .legExtension
        )
    }

    private func checkIn(dayOffset: Int, am: Int) -> DailyCheckInSnapshot {
        DailyCheckInSnapshot(date: day(dayOffset), restingPainAM: am)
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
        response: Response24h = .same
    ) -> TrainingSessionSnapshot {
        session(
            dayOffset: dayOffset,
            type: .hsrStrength,
            sets: sets,
            reps: reps,
            load: load,
            pain: pain,
            whatIDid: "\(PrimaryLoadCatalog.seatedExtension.title) · \(sets)×\(reps) @ \(LoadCopy.labeled(load))",
            response: response
        )
    }

    private func session(
        dayOffset: Int,
        type: SessionType,
        sets: Int,
        reps: Int,
        load: Double,
        pain: Int,
        whatIDid: String,
        response: Response24h = .same
    ) -> TrainingSessionSnapshot {
        let date = day(dayOffset)
        let rows = SessionPrefill.workSets(
            from: LoadPrescription(workingSets: sets, reps: reps, loadLbs: load),
            laterality: .bilateral
        )
        return TrainingSessionSnapshot(
            date: date,
            createdAt: date.addingTimeInterval(60),
            sessionType: type,
            response24h: response,
            decision: response == .pending ? nil : .stay,
            resolvedAt: response == .pending ? nil : date.addingTimeInterval(86_400),
            snoozedUntil: nil,
            phase: .heavySlow,
            painDuring: pain,
            painAfter: pain,
            whatIDid: whatIDid,
            resistanceSets: rows
        )
    }
}
