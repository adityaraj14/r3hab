import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class TwelveWeekPlanTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// Monday 2026-11-09 00:00 UTC.
    private var monday: Date {
        calendar.startOfDay(for: Date(timeIntervalSince1970: 1_794_182_400))
    }

    func testRepRamp() {
        XCTAssertEqual(TwelveWeekPlan.heavyReps(forWeek: 3), 15)
        XCTAssertEqual(TwelveWeekPlan.heavyReps(forWeek: 4), 13)
        XCTAssertEqual(TwelveWeekPlan.heavyReps(forWeek: 5), 12)
        XCTAssertEqual(TwelveWeekPlan.heavyReps(forWeek: 6), 10)
        XCTAssertEqual(TwelveWeekPlan.heavyReps(forWeek: 7), 8)
        XCTAssertEqual(TwelveWeekPlan.heavyReps(forWeek: 8), 7)
        XCTAssertEqual(TwelveWeekPlan.heavyReps(forWeek: 9), 7)
        XCTAssertEqual(TwelveWeekPlan.heavyReps(forWeek: 10), 6)
        XCTAssertEqual(TwelveWeekPlan.heavyReps(forWeek: 11), 6)
        XCTAssertEqual(TwelveWeekPlan.heavyReps(forWeek: 12), 6)
        XCTAssertEqual(TwelveWeekPlan.heavyReps(forWeek: 13), 6)
    }

    func testPhaseFollowsTheWeek() {
        XCTAssertEqual(TwelveWeekPlan.phase(forWeek: 1), .calmTendon)
        XCTAssertEqual(TwelveWeekPlan.phase(forWeek: 2), .calmTendon)
        XCTAssertEqual(TwelveWeekPlan.phase(forWeek: 3), .heavySlow)
        XCTAssertEqual(TwelveWeekPlan.phase(forWeek: 6), .heavySlow)
        XCTAssertEqual(TwelveWeekPlan.phase(forWeek: 7), .heavier)
        XCTAssertEqual(TwelveWeekPlan.phase(forWeek: 10), .heavier)
        XCTAssertEqual(TwelveWeekPlan.phase(forWeek: 11), .springiness)
        XCTAssertEqual(TwelveWeekPlan.phase(forWeek: 20), .springiness)
        XCTAssertEqual(TwelveWeekPlan.openingWeek(for: .aFlareDeLoad), 1)
        XCTAssertEqual(TwelveWeekPlan.openingWeek(for: .bIsometrics), 1)
        XCTAssertEqual(TwelveWeekPlan.openingWeek(for: .cHeavySlowResistance), 3)
    }

    func testMondayWednesdayFridayAndRecovery() {
        let start = monday
        let friday = calendar.date(byAdding: .day, value: 4, to: monday)!
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        let train = TwelveWeekPlan.dayPlan(start: start, on: monday, calendar: calendar)
        XCTAssertEqual(train.kind, .training)
        XCTAssertEqual(train.week, 1)
        XCTAssertEqual(train.exercises.map(\.id), [
            .isometricLegExtension, .singleLegPress, .hipAbduction, .calfRaise
        ])
        XCTAssertEqual(train.exercises[0].holdSeconds, 45)
        XCTAssertEqual(train.exercises[0].sets, 5)
        XCTAssertEqual(train.exercises[0].restSeconds, 120)
        XCTAssertEqual(train.exercises[1].sets, 3)
        XCTAssertEqual(train.exercises[1].reps, 15)
        let also = TwelveWeekPlan.dayPlan(start: start, on: friday, calendar: calendar)
        XCTAssertEqual(also.kind, .training)
        let rest = TwelveWeekPlan.dayPlan(start: start, on: tuesday, calendar: calendar)
        XCTAssertEqual(rest.kind, .recovery)
        XCTAssertTrue(rest.exercises.isEmpty)
        XCTAssertEqual(rest.dailyIsometric.holdSeconds, 45)
        XCTAssertFalse(TwelveWeekPlan.prescribesRunningOrHighVolumeJumping(train))
        XCTAssertFalse(TwelveWeekPlan.prescribesRunningOrHighVolumeJumping(rest))
    }

    func testSpanishSquatIsOptionalAndOnlyInWeeksSevenThroughTen() {
        let start = TwelveWeekPlan.startDate(landingTodayInWeek: 7, today: monday, calendar: calendar)
        let plan = TwelveWeekPlan.dayPlan(start: start, on: monday, calendar: calendar)
        let spanish = plan.exercises.first { $0.id == .spanishSquat }
        XCTAssertEqual(spanish?.sets, 5)
        XCTAssertEqual(spanish?.holdSeconds, 45)
        XCTAssertEqual(spanish?.optional, true)
        XCTAssertEqual(spanish?.note, TwelveWeekPlan.spanishSquatSkipNote)
        let week6 = TwelveWeekPlan.dayPlan(
            start: TwelveWeekPlan.startDate(landingTodayInWeek: 6, today: monday, calendar: calendar),
            on: monday,
            calendar: calendar
        )
        XCTAssertFalse(week6.exercises.contains { $0.id == .spanishSquat })
        XCTAssertFalse(week6.exercises.contains { $0.name.lowercased().contains("run") })
    }

    func testWeeksElevenAndTwelveSplitHeavyAndPlyometricDays() {
        let start = TwelveWeekPlan.startDate(landingTodayInWeek: 11, today: monday, calendar: calendar)
        let heavy = TwelveWeekPlan.dayPlan(start: start, on: monday, calendar: calendar, plyoStage: .landing)
        XCTAssertEqual(heavy.kind, .heavy)
        XCTAssertEqual(heavy.exercises.map(\.id), [.isometricLegExtension, .legExtension, .legPress])
        XCTAssertFalse(heavy.exercises.contains { $0.id == .pogoHop })
        let wednesday = calendar.date(byAdding: .day, value: 2, to: monday)!
        let plyo = TwelveWeekPlan.dayPlan(start: start, on: wednesday, calendar: calendar, plyoStage: .landing)
        XCTAssertEqual(plyo.kind, .plyometric)
        XCTAssertEqual(plyo.exercises.map(\.id), [.pogoHop, .boxJumpUp, .landing])
        XCTAssertEqual(plyo.exercises[0].sets, 3)
        XCTAssertEqual(plyo.exercises[0].reps, 20)
        XCTAssertEqual(plyo.exercises[1].reps, 8)
        XCTAssertEqual(plyo.exercises[2].reps, 5)
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        XCTAssertEqual(TwelveWeekPlan.dayPlan(start: start, on: tuesday, calendar: calendar).kind, .recovery)
        XCTAssertFalse(TwelveWeekPlan.prescribesRunningOrHighVolumeJumping(heavy))
        XCTAssertFalse(TwelveWeekPlan.prescribesRunningOrHighVolumeJumping(plyo))
    }

    func testNoRunningOrHighVolumeJumpingBeforeWeekEleven() {
        for week in 1...10 {
            let start = TwelveWeekPlan.startDate(landingTodayInWeek: week, today: monday, calendar: calendar)
            for offset in 0..<7 {
                let day = calendar.date(byAdding: .day, value: offset, to: monday)!
                let plan = TwelveWeekPlan.dayPlan(start: start, on: day, calendar: calendar, plyoStage: .landing)
                XCTAssertFalse(TwelveWeekPlan.prescribesRunningOrHighVolumeJumping(plan), "week \(week) offset \(offset)")
            }
        }
    }

    func testPlyoAdvancesOnlyAfterAQuietMorning() {
        let sunday = calendar.date(byAdding: .day, value: -1, to: monday)!
        let pogo = plyoSession(on: sunday, name: "Pogo hop", pain: 2)
        let quiet = [
            DailyCheckInSnapshot(date: sunday, restingPainAM: 1),
            DailyCheckInSnapshot(date: monday, restingPainAM: 1)
        ]
        let advanced = TwelveWeekPlan.plyoGate(sessions: [pogo], checkIns: quiet, asOf: monday, calendar: calendar)
        XCTAssertEqual(advanced.stage, .boxJump)
        XCTAssertNil(advanced.note)

        let flared = [
            DailyCheckInSnapshot(date: sunday, restingPainAM: 1),
            DailyCheckInSnapshot(date: monday, restingPainAM: 3)
        ]
        let held = TwelveWeekPlan.plyoGate(sessions: [pogo], checkIns: flared, asOf: monday, calendar: calendar)
        XCTAssertEqual(held.stage, .pogo)
        XCTAssertNotNil(held.note)

        let hot = plyoSession(on: sunday, name: "Pogo hop", pain: 4)
        let blocked = TwelveWeekPlan.plyoGate(sessions: [hot], checkIns: quiet, asOf: monday, calendar: calendar)
        XCTAssertEqual(blocked.stage, .pogo)

        let missing = TwelveWeekPlan.plyoGate(sessions: [pogo], checkIns: [], asOf: monday, calendar: calendar)
        XCTAssertEqual(missing.stage, .pogo)
    }

    func testDeclineTrendGoesDownAndAsksWhenThisWeekIsMissing() {
        let start = monday
        let week1 = monday
        let week2 = calendar.date(byAdding: .day, value: 7, to: monday)!
        let later = calendar.date(byAdding: .day, value: 8, to: monday)!
        let trend = TwelveWeekPlan.declineTrend(
            start: start,
            checkIns: [
                DailyCheckInSnapshot(date: week1, restingPainAM: 1, declineSquatL: 4, declineSquatR: 2),
                DailyCheckInSnapshot(date: week2, restingPainAM: 1, declineSquatL: 3)
            ],
            asOf: later,
            calendar: calendar
        )
        XCTAssertEqual(trend.direction, .down)
        XCTAssertEqual(trend.points.map(\.score), [4, 3])
        XCTAssertEqual(trend.headline, "The decline squat pain is going down.")
        XCTAssertFalse(trend.needsTest)

        let early = TwelveWeekPlan.declineTrend(
            start: start,
            checkIns: [],
            asOf: monday,
            calendar: calendar
        )
        XCTAssertEqual(early.direction, .notEnough)
        XCTAssertTrue(early.needsTest)
    }

    func testNextSessionDaySkipsTheRestDay() {
        let start = monday
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        let wednesday = calendar.date(byAdding: .day, value: 2, to: monday)!
        XCTAssertEqual(
            TwelveWeekPlan.nextSessionDay(from: tuesday, start: start, calendar: calendar),
            wednesday
        )
        XCTAssertEqual(
            TwelveWeekPlan.nextSessionDay(from: monday, start: start, calendar: calendar),
            wednesday
        )
    }

    func testProgramWeekRollsFromTheStartDate() {
        let start = monday
        let nextMonday = calendar.date(byAdding: .day, value: 7, to: monday)!
        XCTAssertEqual(TwelveWeekPlan.programWeek(start: start, on: monday, calendar: calendar), 1)
        XCTAssertEqual(TwelveWeekPlan.programWeek(start: start, on: nextMonday, calendar: calendar), 2)
        XCTAssertTrue(TwelveWeekPlan.isUnsetStart(Date(timeIntervalSince1970: 0)))
        XCTAssertFalse(TwelveWeekPlan.isUnsetStart(monday))
    }

    private func plyoSession(on date: Date, name: String, pain: Int) -> TrainingSessionSnapshot {
        TrainingSessionSnapshot(
            date: date,
            createdAt: date.addingTimeInterval(60),
            sessionType: .energyStorage,
            response24h: .same,
            decision: .stay,
            resolvedAt: date.addingTimeInterval(3_600),
            snoozedUntil: nil,
            phase: .springiness,
            painDuring: pain,
            whatIDid: name,
            resistanceSets: [ResistanceSet(reps: 20, loadLbs: nil, isWarmup: false)]
        )
    }
}
