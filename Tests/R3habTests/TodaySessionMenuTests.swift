import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class TodaySessionMenuTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// Monday 2026-11-09 00:00 UTC.
    private var monday: Date {
        calendar.startOfDay(for: Date(timeIntervalSince1970: 1_794_182_400))
    }

    func testWeekThreeMondayLinkNamesTheDayAndHidesTheExerciseList() {
        let plan = plan(week: 3, on: monday)
        let link = TodaySessionMenu.link(
            plan: plan,
            on: monday,
            calendar: calendar,
            todaySessions: [],
            hasDraft: false
        )
        let exercises = TodaySessionMenu.listedExercises(in: plan)

        XCTAssertEqual(link.title, "Monday — Week 3 HSR")
        XCTAssertEqual(exercises.count, 3)
        XCTAssertEqual(link.exerciseCount, 3)
        XCTAssertEqual(link.detail, "3 exercises")
        XCTAssertEqual(link.status, .notDone)
        XCTAssertEqual(link.status.label, "Not done")
        XCTAssertFalse(link.isRestDay)
        for exercise in exercises {
            XCTAssertFalse(link.title.contains(exercise.name))
            XCTAssertFalse(link.detail.contains(exercise.name))
            XCTAssertFalse(link.detail.contains(exercise.doseLine))
        }
        guard let lift = exercises.first(where: { $0.id == .legExtension }) else {
            return XCTFail("Week 3 is missing the seated leg extension")
        }
        XCTAssertTrue(lift.doseLine.contains("4×15"))
        XCTAssertTrue(lift.doseLine.contains("3 seconds up, 3 seconds down"))
        XCTAssertFalse(lift.note?.isEmpty ?? true)
    }

    func testWeekOneTrainingDayIsIsometrics() {
        let plan = plan(week: 1, on: monday)
        let link = TodaySessionMenu.link(
            plan: plan,
            on: monday,
            calendar: calendar,
            todaySessions: [],
            hasDraft: false
        )
        XCTAssertEqual(link.title, "Monday — Week 1 Isometrics")
        XCTAssertEqual(link.exerciseCount, 4)
        XCTAssertEqual(link.detail, "4 exercises")
        XCTAssertEqual(link.status, .notDone)
    }

    func testHeavierAndPlyoDaysUseTheirOwnTags() {
        let heavier = TodaySessionMenu.link(
            plan: plan(week: 7, on: monday),
            on: monday,
            calendar: calendar,
            todaySessions: [],
            hasDraft: false
        )
        XCTAssertEqual(heavier.title, "Monday — Week 7 Heavier")
        let heavy = TodaySessionMenu.link(
            plan: plan(week: 11, on: monday),
            on: monday,
            calendar: calendar,
            todaySessions: [],
            hasDraft: false
        )
        XCTAssertEqual(heavy.title, "Monday — Week 11 HSR")

        let wednesday = calendar.date(byAdding: .day, value: 2, to: monday)!
        let plyoPlan = TwelveWeekPlan.dayPlan(
            start: TwelveWeekPlan.startDate(landingTodayInWeek: 11, today: monday, calendar: calendar),
            on: wednesday,
            calendar: calendar,
            plyoStage: .landing,
            plyoNote: "Repeat the landing drill."
        )
        let plyo = TodaySessionMenu.link(
            plan: plyoPlan,
            on: wednesday,
            calendar: calendar,
            todaySessions: [],
            hasDraft: false
        )
        XCTAssertEqual(plyo.title, "Wednesday — Week 11 Plyo")
        XCTAssertEqual(
            TodaySessionMenu.listedExercises(in: plyoPlan).map(\.id),
            [.isometricLegExtension, .pogoHop, .boxJumpUp, .landing]
        )
        XCTAssertEqual(plyo.detail, "4 exercises")
        XCTAssertFalse(plyo.detail.contains("Repeat the landing drill."))
        XCTAssertEqual(plyoPlan.plyoNote, "Repeat the landing drill.")
    }

    func testRestDayLinkKeepsRestCopyInsteadOfTheExerciseMenu() {
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        let plan = plan(week: 3, on: tuesday)
        let link = TodaySessionMenu.link(
            plan: plan,
            on: tuesday,
            calendar: calendar,
            todaySessions: [],
            hasDraft: false
        )
        XCTAssertTrue(link.isRestDay)
        XCTAssertEqual(link.title, "Tuesday — Week 3")
        XCTAssertEqual(link.status, .rest)
        XCTAssertEqual(link.status.label, "Rest day")
        XCTAssertEqual(link.detail, plan.summary)
        XCTAssertTrue(link.detail.contains("Walk or stretch"))
        XCTAssertEqual(link.exerciseCount, 1)
        XCTAssertEqual(TodaySessionMenu.listedExercises(in: plan).map(\.id), [.isometricLegExtension])
        XCTAssertFalse(link.detail.contains("5 holds"))
        XCTAssertFalse(link.title.contains("HSR"))
    }

    func testDraftAndPartialLogsAreInProgressUntilEveryRequiredExerciseIsLogged() {
        let plan = plan(week: 7, on: monday)
        let exercises = TodaySessionMenu.listedExercises(in: plan)
        XCTAssertTrue(exercises.contains { $0.id == .spanishSquat && $0.optional })

        let draft = TodaySessionMenu.link(
            plan: plan,
            on: monday,
            calendar: calendar,
            todaySessions: [],
            hasDraft: true
        )
        XCTAssertEqual(draft.status, .inProgress)

        let partial = TodaySessionMenu.link(
            plan: plan,
            on: monday,
            calendar: calendar,
            todaySessions: [session(on: monday, type: .hsrStrength, name: "Leg press")],
            hasDraft: false
        )
        XCTAssertEqual(partial.status, .inProgress)
        XCTAssertEqual(
            TodaySessionMenu.loggedKinds(exercises: exercises, sessions: partialSessions(on: monday)),
            [.legPress]
        )

        let required = [
            session(on: monday, type: .isometrics, name: "Seated leg extension hold"),
            session(on: monday, type: .hsrStrength, name: "Seated leg extension"),
            session(on: monday, type: .hsrStrength, name: "Leg press")
        ]
        let done = TodaySessionMenu.link(
            plan: plan,
            on: monday,
            calendar: calendar,
            todaySessions: required,
            hasDraft: false
        )
        XCTAssertEqual(done.status, .done)
        XCTAssertFalse(TodaySessionMenu.loggedKinds(exercises: exercises, sessions: required).contains(.spanishSquat))
    }

    func testLoggingTheRestDayHoldMarksItDone() {
        let tuesday = calendar.date(byAdding: .day, value: 1, to: monday)!
        let plan = plan(week: 3, on: tuesday)
        let logged = TodaySessionMenu.link(
            plan: plan,
            on: tuesday,
            calendar: calendar,
            todaySessions: [session(on: tuesday, type: .isometrics, name: "Seated leg extension hold")],
            hasDraft: false
        )
        XCTAssertEqual(logged.status, .done)
        XCTAssertEqual(logged.detail, plan.summary)
    }

    private func plan(week: Int, on date: Date) -> DayPlan {
        TwelveWeekPlan.dayPlan(
            start: TwelveWeekPlan.startDate(landingTodayInWeek: week, today: monday, calendar: calendar),
            on: date,
            calendar: calendar
        )
    }

    private func partialSessions(on date: Date) -> [TrainingSessionSnapshot] {
        [session(on: date, type: .hsrStrength, name: "Leg press")]
    }

    private func session(on date: Date, type: SessionType, name: String) -> TrainingSessionSnapshot {
        TrainingSessionSnapshot(
            date: date,
            createdAt: date.addingTimeInterval(60),
            sessionType: type,
            response24h: .pending,
            decision: nil,
            resolvedAt: nil,
            snoozedUntil: nil,
            phase: .heavySlow,
            painDuring: 2,
            whatIDid: name
        )
    }
}
