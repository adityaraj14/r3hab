import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class PlanScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    /// Monday 2026-11-09 00:00 UTC. Week 1 of a plan that starts this day.
    private var monday: Date {
        calendar.startOfDay(for: Date(timeIntervalSince1970: 1_794_182_400))
    }

    private func day(_ offset: Int, from base: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: base)!
    }

    private func resolve(
        on date: Date,
        sessions: [TrainingSessionSnapshot] = [],
        overrides: [PlanSessionOverride] = [],
        start: Date? = nil
    ) -> PlanScheduleSnapshot {
        PlanSchedule.resolve(
            start: start ?? monday,
            on: date,
            sessions: sessions,
            overrides: overrides,
            calendar: calendar
        )
    }

    func testCalendarScheduleIsUnchangedWithoutAnOverride() {
        let tuesday = day(1, from: monday)
        let wednesday = day(2, from: monday)
        let mondayPlan = resolve(on: monday)
        XCTAssertEqual(mondayPlan.kind, .training)
        XCTAssertEqual(mondayPlan.programWeek, 1)
        XCTAssertEqual(mondayPlan.phase, .calmTendon)
        XCTAssertEqual(mondayPlan.prescriptionDate, monday)
        XCTAssertNil(mondayPlan.fulfillsScheduledDate)
        XCTAssertEqual(mondayPlan.nextSessionDate, wednesday)
        XCTAssertTrue(mondayPlan.missedSlotDates.isEmpty)
        XCTAssertEqual(mondayPlan.fulfilledThisWeek, 0)

        let rest = resolve(on: tuesday)
        XCTAssertEqual(rest.kind, .recovery)
        XCTAssertFalse(rest.deferredBySpacing)
        XCTAssertEqual(rest.nextSessionDate, wednesday)
        XCTAssertEqual(
            rest.restLine(calendar: calendar),
            "The seated hold is optional today. Next training day is Wednesday."
        )
    }

    func testMissedMondayLoggedTuesdayIsNotMissedAndShiftsTheNextSession() {
        let tuesday = day(1, from: monday)
        let wednesday = day(2, from: monday)
        let thursday = day(3, from: monday)
        let makeup = PlanSessionOverride(scheduledDate: monday, performedDate: tuesday)
        let logged = heavySession(on: tuesday, name: "Seated leg extension hold")

        let open = resolve(on: tuesday)
        XCTAssertTrue(open.missedSlotDates.contains(monday))
        XCTAssertEqual(open.fulfilledThisWeek, 0)

        let done = resolve(on: tuesday, sessions: [logged], overrides: [makeup])
        XCTAssertFalse(done.missedSlotDates.contains(monday))
        XCTAssertEqual(done.kind, .training)
        XCTAssertEqual(done.fulfillsScheduledDate, monday)
        XCTAssertEqual(done.prescriptionDate, monday)
        XCTAssertEqual(done.fulfilledThisWeek, 1)
        XCTAssertEqual(done.programWeek, 1)
        XCTAssertEqual(done.phase, .calmTendon)
        XCTAssertEqual(done.nextSessionDate, thursday)

        let wed = resolve(on: wednesday, sessions: [logged], overrides: [makeup])
        XCTAssertEqual(wed.kind, .recovery)
        XCTAssertTrue(wed.deferredBySpacing)
        XCTAssertEqual(wed.nextSessionDate, thursday)
        XCTAssertFalse(wed.missedSlotDates.contains(wednesday))
        XCTAssertEqual(
            wed.restLine(calendar: calendar),
            "Keep two days between heavy sessions. Next training day is Thursday."
        )

        let plan = PlanSchedule.dayPlan(
            start: monday,
            on: tuesday,
            sessions: [logged],
            checkIns: [],
            overrides: [makeup],
            calendar: calendar
        )
        XCTAssertEqual(plan.kind, .training)
        XCTAssertEqual(plan.exercises.map(\.id), [
            .isometricLegExtension, .singleLegPress, .hipAbduction, .calfRaise
        ])
        XCTAssertEqual(plan.week, 1)
        XCTAssertEqual(plan.phase, .calmTendon)
        XCTAssertEqual(plan.fulfillsScheduledDate, monday)
        XCTAssertTrue(plan.summary.hasPrefix("Make-up for Monday."))
    }

    func testMakeupOnARestDayUsesTheMissedSessionsWork() {
        let tuesday = day(1, from: monday)
        let makeup = PlanSessionOverride(scheduledDate: monday, performedDate: tuesday)
        let snapshot = resolve(on: tuesday, overrides: [makeup])
        XCTAssertEqual(snapshot.kind, .training)
        XCTAssertNotEqual(TwelveWeekPlan.dayKind(week: 1, weekday: calendar.component(.weekday, from: tuesday)), .training)
        XCTAssertEqual(snapshot.fulfillsScheduledDate, monday)
        XCTAssertFalse(snapshot.missedSlotDates.contains(monday))
    }

    func testFridayLoggedTheNextMondayDoesNotAdvanceWeekPhaseOrLoad() {
        let friday = day(4 + 5 * 7, from: monday)
        let nextMonday = day(7 * 6, from: monday)
        XCTAssertEqual(TwelveWeekPlan.programWeek(start: monday, on: friday, calendar: calendar), 6)
        XCTAssertEqual(TwelveWeekPlan.programWeek(start: monday, on: nextMonday, calendar: calendar), 7)
        XCTAssertEqual(TwelveWeekPlan.phase(forWeek: 6), .heavySlow)
        XCTAssertEqual(TwelveWeekPlan.phase(forWeek: 7), .heavier)

        let makeup = PlanSessionOverride(scheduledDate: friday, performedDate: nextMonday)
        let logged = heavySession(on: nextMonday, name: "Seated leg extension", reps: 10, load: 40)
        let checkIns = [
            DailyCheckInSnapshot(date: nextMonday, restingPainAM: 1),
            DailyCheckInSnapshot(date: day(1, from: nextMonday), restingPainAM: 1)
        ]
        let snapshot = resolve(on: nextMonday, sessions: [logged], overrides: [makeup])
        XCTAssertEqual(snapshot.programWeek, 7)
        XCTAssertEqual(snapshot.phase, .heavier)
        XCTAssertNotEqual(snapshot.phase, .springiness)
        XCTAssertEqual(snapshot.prescriptionDate, friday)
        XCTAssertFalse(snapshot.missedSlotDates.contains(friday))
        XCTAssertEqual(snapshot.fulfilledThisWeek, 0)
        XCTAssertEqual(snapshot.nextSessionDate, day(2, from: nextMonday))

        let advice = TwelveWeekPlan.advise(
            kind: .legExtension,
            programStart: monday,
            sessions: [logged],
            checkIns: checkIns,
            asOf: nextMonday,
            calendar: calendar,
            overrides: [makeup]
        )
        XCTAssertEqual(advice.target.reps, TwelveWeekPlan.heavyReps(forWeek: 6))
        XCTAssertEqual(advice.stance, .hold)
        XCTAssertEqual(advice.target.loadLbs, 40)

        let without = TwelveWeekPlan.advise(
            kind: .legExtension,
            programStart: monday,
            sessions: [logged],
            checkIns: checkIns,
            asOf: nextMonday,
            calendar: calendar
        )
        XCTAssertEqual(without.target.reps, TwelveWeekPlan.heavyReps(forWeek: 7))
    }

    func testLoggingTheShiftedDayFulfillsTheDeferredSession() {
        let tuesday = day(1, from: monday)
        let wednesday = day(2, from: monday)
        let thursday = day(3, from: monday)
        let friday = day(4, from: monday)
        let makeup = PlanSessionOverride(scheduledDate: monday, performedDate: tuesday)
        let mondayLog = heavySession(on: tuesday, name: "Seated leg extension hold")
        let thursdayLog = heavySession(on: thursday, name: "Single-leg leg press")
        let viewed = resolve(
            on: friday,
            sessions: [mondayLog, thursdayLog],
            overrides: [makeup]
        )
        XCTAssertFalse(viewed.missedSlotDates.contains(wednesday))
        XCTAssertEqual(viewed.nextSessionDate, day(1, from: friday))
    }

    func testUndoOverrideMakesThePlannedDayMissedAgain() {
        let tuesday = day(1, from: monday)
        let wednesday = day(2, from: monday)
        let makeup = PlanSessionOverride(id: UUID(), scheduledDate: monday, performedDate: tuesday)
        let logged = heavySession(on: tuesday, name: "Seated leg extension hold")
        var stored = PlanOverrideStore.upsert(makeup, into: [])
        XCTAssertEqual(stored.map(\.id), [makeup.id])

        let honored = resolve(on: tuesday, sessions: [logged], overrides: stored)
        XCTAssertFalse(honored.missedSlotDates.contains(monday))
        XCTAssertEqual(honored.nextSessionDate, day(3, from: monday))

        stored = PlanOverrideStore.removing(id: makeup.id, from: stored)
        XCTAssertTrue(stored.isEmpty)
        let undone = resolve(on: tuesday, sessions: [logged], overrides: stored)
        XCTAssertTrue(undone.missedSlotDates.contains(monday))
        XCTAssertEqual(undone.kind, .recovery)
        XCTAssertEqual(undone.fulfilledThisWeek, 0)
        // The log is still Tuesday, so Wednesday stays inside the rest window.
        XCTAssertEqual(undone.nextSessionDate, day(3, from: monday))
        XCTAssertNotEqual(undone.nextSessionDate, wednesday)
    }

    func testDeclineTestWaitsForTheMovedSessionAndStaysInThatWeek() {
        let tuesday = day(1, from: monday)
        let makeup = PlanSessionOverride(scheduledDate: monday, performedDate: tuesday)
        let early = TwelveWeekPlan.declineTrend(
            start: monday,
            checkIns: [],
            asOf: monday,
            calendar: calendar,
            overrides: [makeup]
        )
        XCTAssertFalse(early.needsTest)

        let due = TwelveWeekPlan.declineTrend(
            start: monday,
            checkIns: [],
            asOf: tuesday,
            calendar: calendar,
            overrides: [makeup]
        )
        XCTAssertTrue(due.needsTest)
        XCTAssertEqual(
            PlanSchedule.declineDueDate(
                start: monday,
                asOf: tuesday,
                sessions: [],
                overrides: [makeup],
                calendar: calendar
            ),
            tuesday
        )

        let logged = TwelveWeekPlan.declineTrend(
            start: monday,
            checkIns: [DailyCheckInSnapshot(date: tuesday, restingPainAM: 1, declineSquatL: 3)],
            asOf: tuesday,
            calendar: calendar,
            overrides: [makeup]
        )
        XCTAssertFalse(logged.needsTest)
        XCTAssertEqual(logged.points.map(\.week), [1])
        XCTAssertEqual(logged.points.map(\.score), [3])
    }

    func testNextMorningStillUsesTheDayTheSessionWasDone() {
        let tuesday = day(1, from: monday)
        let wednesday = day(2, from: monday)
        let makeup = PlanSessionOverride(scheduledDate: monday, performedDate: tuesday)
        let logged = heavySession(on: tuesday, name: "Seated leg extension hold", load: 30)
        let advice = TwelveWeekPlan.advise(
            kind: .isometricLegExtension,
            programStart: monday,
            sessions: [logged],
            checkIns: [
                DailyCheckInSnapshot(date: tuesday, restingPainAM: 1),
                DailyCheckInSnapshot(date: wednesday, restingPainAM: 4)
            ],
            asOf: wednesday,
            calendar: calendar,
            overrides: [makeup]
        )
        XCTAssertEqual(advice.stance, .drop)
        XCTAssertEqual(advice.target.loadLbs, 25)
        XCTAssertEqual(advice.reason, TwelveWeekPlan.reasonDropOneSession)
        XCTAssertEqual(
            PlanSchedule.planDate(for: logged, overrides: [makeup], calendar: calendar),
            monday
        )
    }

    func testOverrideStoreRoundTripsAndReplacesTheSamePlannedDay() {
        let tuesday = day(1, from: monday)
        let wednesday = day(2, from: monday)
        let first = PlanSessionOverride(scheduledDate: monday, performedDate: tuesday, sessionID: UUID())
        let encoded = PlanOverrideStore.encode([first])
        let decoded = PlanOverrideStore.decode(encoded)
        XCTAssertEqual(decoded, [first])
        XCTAssertEqual(PlanOverrideStore.decode(""), [])
        XCTAssertEqual(PlanOverrideStore.decode("not json"), [])

        let moved = PlanSessionOverride(scheduledDate: monday, performedDate: wednesday, sessionID: first.sessionID)
        let replaced = PlanOverrideStore.upsert(moved, into: decoded)
        XCTAssertEqual(replaced.count, 1)
        XCTAssertEqual(replaced[0].performedDate, wednesday)
        XCTAssertEqual(replaced[0].sessionID, first.sessionID)

        let again = PlanOverrideStore.encode(replaced)
        XCTAssertEqual(PlanOverrideStore.decode(again), replaced)
    }

    private func heavySession(
        on date: Date,
        name: String,
        reps: Int = 15,
        load: Double = 20
    ) -> TrainingSessionSnapshot {
        TrainingSessionSnapshot(
            date: date,
            createdAt: date.addingTimeInterval(3_600),
            sessionType: name.contains("hold") ? .isometrics : .hsrStrength,
            response24h: .same,
            decision: .stay,
            resolvedAt: date.addingTimeInterval(7_200),
            snoozedUntil: nil,
            phase: .calmTendon,
            painDuring: 2,
            painAfter: 1,
            whatIDid: name,
            resistanceSets: [ResistanceSet(reps: reps, loadLbs: load, isWarmup: false)]
        )
    }
}
