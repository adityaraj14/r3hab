import XCTest
@testable import R3hab

final class WorkoutStreakTests: XCTestCase {
    /// Fixed local calendar so day boundaries in these tests never depend on
    /// the machine running them.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    /// Local wall-clock moment on a Monday (2026-03-02) plus `day` days.
    private func at(day: Int, hour: Int, minute: Int = 0) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let dayStart = calendar.date(byAdding: .day, value: day, to: base)!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart)!
    }

    /// Mirrors `TrainingSession.init`: `date` is the start of the trained day,
    /// `createdAt` is the clock moment the session was logged.
    private func snap(
        createdAt: Date,
        type: SessionType = .isometrics,
        date: Date? = nil
    ) -> TrainingSessionSnapshot {
        TrainingSessionSnapshot(
            id: UUID(),
            date: calendar.startOfDay(for: date ?? createdAt),
            createdAt: createdAt,
            sessionType: type,
            response24h: .pending,
            decision: nil,
            resolvedAt: nil,
            snoozedUntil: nil,
            phase: .bIsometrics
        )
    }

    private func evaluate(_ sessions: [TrainingSessionSnapshot], now: Date) -> WorkoutStreak.Snapshot {
        WorkoutStreak.evaluate(sessions: sessions, now: now, calendar: calendar)
    }

    func testEmptyHasZeroStreakAndNoMiss() {
        let result = evaluate([], now: at(day: 0, hour: 12))
        XCTAssertEqual(result.current, 0)
        XCTAssertEqual(result.lastChain, 0)
        XCTAssertEqual(result.best, 0)
        XCTAssertEqual(result.miss, .none)
        XCTAssertNil(result.lastHardDay)
        XCTAssertNil(result.daysSinceLastHard)
    }

    func testSingleHardSessionIsLiveOnTheDayAfter() {
        let result = evaluate([snap(createdAt: at(day: 0, hour: 7))], now: at(day: 1, hour: 20))
        XCTAssertEqual(result.current, 1)
        XCTAssertEqual(result.lastChain, 1)
        XCTAssertEqual(result.best, 1)
        XCTAssertEqual(result.daysSinceLastHard, 1)
        XCTAssertEqual(result.miss, .none)
    }

    // MARK: Calendar-day grace on the due day

    /// Adi’s case: 7 AM two days ago, 5 PM today. 58 hours on the clock, but the
    /// workout landed on the due calendar day — not a miss, chain unbroken.
    func testSevenAMThenFivePMOnDueDayIsNotAMiss() {
        let sessions = [
            snap(createdAt: at(day: 0, hour: 7)),
            snap(createdAt: at(day: 2, hour: 17))
        ]
        let gapHours = sessions[1].createdAt.timeIntervalSince(sessions[0].createdAt) / 3600
        XCTAssertEqual(gapHours, 58, accuracy: 0.01, "Sanity: this gap would have broken a strict 48h rule.")

        let result = evaluate(sessions, now: at(day: 2, hour: 17, minute: 5))
        XCTAssertEqual(result.current, 2, "Both sessions are one chain.")
        XCTAssertEqual(result.lastChain, 2)
        XCTAssertEqual(result.best, 2)
        XCTAssertEqual(result.miss, .none)
    }

    func testWholeDueDayStaysLiveBeforeAnyWorkout() {
        let sessions = [snap(createdAt: at(day: 0, hour: 7))]

        let morning = evaluate(sessions, now: at(day: 2, hour: 6))
        XCTAssertEqual(morning.current, 1, "Due-day morning: chain still live.")
        XCTAssertEqual(morning.miss, .approaching)

        let lateNight = evaluate(sessions, now: at(day: 2, hour: 23, minute: 59))
        XCTAssertEqual(lateNight.current, 1, "One minute before the due day ends: still live, still not a miss.")
        XCTAssertEqual(lateNight.daysSinceLastHard, 2)
        XCTAssertEqual(lateNight.miss, .approaching)
    }

    func testMissStartsOnlyWhenTheDueDayHasEnded() {
        let sessions = [snap(createdAt: at(day: 0, hour: 7))]

        let justAfterMidnight = evaluate(sessions, now: at(day: 3, hour: 0, minute: 1))
        XCTAssertEqual(justAfterMidnight.current, 0)
        XCTAssertEqual(justAfterMidnight.lastChain, 1)
        XCTAssertEqual(justAfterMidnight.daysSinceLastHard, 3)
        XCTAssertEqual(justAfterMidnight.miss, .oneMiss)

        let secondDueDayGone = evaluate(sessions, now: at(day: 5, hour: 9))
        XCTAssertEqual(secondDueDayGone.miss, .twoMiss)
    }

    func testThreeCalendarDayGapBreaksTheChain() {
        let sessions = [
            snap(createdAt: at(day: 0, hour: 7)),
            snap(createdAt: at(day: 3, hour: 7)),
            snap(createdAt: at(day: 5, hour: 7))
        ]
        let result = evaluate(sessions, now: at(day: 5, hour: 9))
        XCTAssertEqual(result.current, 2, "Day 3 started a new chain; day 5 continued it.")
        XCTAssertEqual(result.lastChain, 2)
        XCTAssertEqual(result.best, 2)
        XCTAssertEqual(result.miss, .none)
    }

    func testLateNightThenEarlyMorningTwoDaysLaterKeepsTheChain() {
        // 23:00 on day 0 → 06:00 on day 2 is only 31 hours but spans two day
        // boundaries; the calendar rule still treats it as on-time.
        let sessions = [
            snap(createdAt: at(day: 0, hour: 23)),
            snap(createdAt: at(day: 2, hour: 6))
        ]
        let result = evaluate(sessions, now: at(day: 2, hour: 7))
        XCTAssertEqual(result.current, 2)
        XCTAssertEqual(result.miss, .none)
    }

    func testBackfilledSessionCountsForTheDayTrained() {
        // Trained on day 2 but only logged it on day 3: `date` is day 2, so the
        // chain from day 0 is kept and nothing is missed on day 3.
        let sessions = [
            snap(createdAt: at(day: 0, hour: 7)),
            snap(createdAt: at(day: 3, hour: 9), date: at(day: 2, hour: 0))
        ]
        let result = evaluate(sessions, now: at(day: 3, hour: 10))
        XCTAssertEqual(result.current, 2)
        XCTAssertEqual(result.daysSinceLastHard, 1)
        XCTAssertEqual(result.miss, .none)
        XCTAssertEqual(result.lastHardDay, at(day: 2, hour: 0))
    }

    // MARK: Existing chain semantics

    func testOtherSessionsAreIgnored() {
        let sessions = [
            snap(createdAt: at(day: 0, hour: 8), type: .other),
            snap(createdAt: at(day: 1, hour: 8), type: .hsrStrength)
        ]
        let result = evaluate(sessions, now: at(day: 1, hour: 12))
        XCTAssertEqual(result.current, 1)
        XCTAssertEqual(result.best, 1)
    }

    func testOtherSessionsDoNotCountAsHardForTheChain() {
        XCTAssertFalse(SessionSpacing.isHard(.other))

        let easyThenLift = [
            snap(createdAt: at(day: 0, hour: 8), type: .other),
            snap(createdAt: at(day: 1, hour: 8), type: .hsrStrength)
        ]
        let result = evaluate(easyThenLift, now: at(day: 1, hour: 12))
        XCTAssertEqual(result.current, 1, "Easy work is not a link — only loaded sessions keep the chain.")

        let easyOnly = [
            snap(createdAt: at(day: 0, hour: 8), type: .other),
            snap(createdAt: at(day: 0, hour: 18), type: .other)
        ]
        let easyStreak = evaluate(easyOnly, now: at(day: 0, hour: 20))
        XCTAssertEqual(easyStreak.current, 0)
        XCTAssertNil(easyStreak.lastHardDay)
    }

    func testSameDayDoublesEachCountAsALink() {
        let morning = at(day: 0, hour: 8)
        let evening = at(day: 0, hour: 13)
        let sessions = [
            snap(createdAt: morning, type: .isometrics, date: morning),
            snap(createdAt: evening, type: .hsrStrength, date: morning)
        ]
        let result = evaluate(sessions, now: at(day: 0, hour: 16))
        XCTAssertEqual(result.current, 2, "Two hard sessions the same day are two Process votes.")
    }

    func testLiveStreakDropsAfterTheDueDayAndRemembersTheChain() {
        let sessions = [
            snap(createdAt: at(day: 0, hour: 7)),
            snap(createdAt: at(day: 2, hour: 7))
        ]
        let result = evaluate(sessions, now: at(day: 5, hour: 9))
        XCTAssertEqual(result.current, 0)
        XCTAssertEqual(result.lastChain, 2)
        XCTAssertEqual(result.miss, .oneMiss)
    }

    func testRestDayIsOnlyTheDayBetweenSessions() {
        let sessions = [snap(createdAt: at(day: 0, hour: 7))]
        XCTAssertFalse(evaluate([], now: at(day: 0, hour: 12)).isRestDay, "Nothing trained yet: the lift is due.")
        XCTAssertFalse(evaluate(sessions, now: at(day: 0, hour: 12)).isRestDay, "Day of the session.")
        XCTAssertTrue(evaluate(sessions, now: at(day: 1, hour: 6)).isRestDay)
        XCTAssertTrue(evaluate(sessions, now: at(day: 1, hour: 23, minute: 59)).isRestDay, "Whole rest day.")
        XCTAssertFalse(evaluate(sessions, now: at(day: 2, hour: 0, minute: 1)).isRestDay, "Due day: promote the lift.")
        XCTAssertFalse(evaluate(sessions, now: at(day: 3, hour: 9)).isRestDay, "Missed: still not a rest day.")
    }

    func testOptionalLiftOnARestDayResetsTheCadence() {
        // Trained day 0 and again on the rest day (day 1): day 2 becomes the
        // new rest day and day 3 the due day.
        let sessions = [
            snap(createdAt: at(day: 0, hour: 7)),
            snap(createdAt: at(day: 1, hour: 18))
        ]
        XCTAssertFalse(evaluate(sessions, now: at(day: 1, hour: 19)).isRestDay)
        XCTAssertTrue(evaluate(sessions, now: at(day: 2, hour: 9)).isRestDay)
        XCTAssertEqual(evaluate(sessions, now: at(day: 3, hour: 9)).miss, .approaching)
        XCTAssertEqual(evaluate(sessions, now: at(day: 3, hour: 9)).current, 2)
    }

    func testMissStatesByCalendarDay() {
        XCTAssertEqual(SessionSpacing.hardCadenceDays, 2)
        XCTAssertEqual(WorkoutStreak.missState(daysSinceLastHard: 0), .none)
        XCTAssertEqual(WorkoutStreak.missState(daysSinceLastHard: 1), .none)
        XCTAssertEqual(WorkoutStreak.missState(daysSinceLastHard: 2), .approaching)
        XCTAssertEqual(WorkoutStreak.missState(daysSinceLastHard: 3), .oneMiss)
        XCTAssertEqual(WorkoutStreak.missState(daysSinceLastHard: 4), .oneMiss)
        XCTAssertEqual(WorkoutStreak.missState(daysSinceLastHard: 5), .twoMiss)
    }

    func testCalendarDaysIgnoresClockTime() {
        XCTAssertEqual(
            SessionSpacing.calendarDays(from: at(day: 0, hour: 7), to: at(day: 2, hour: 17), calendar: calendar),
            2
        )
        XCTAssertEqual(
            SessionSpacing.calendarDays(from: at(day: 0, hour: 23, minute: 59), to: at(day: 1, hour: 0), calendar: calendar),
            1
        )
    }

    func testStreakStatusIsOneShortWordPerMissState() {
        XCTAssertNil(WorkoutStreak.statusLabel(for: .none))
        XCTAssertEqual(WorkoutStreak.statusLabel(for: .approaching), "Due today")
        XCTAssertEqual(WorkoutStreak.statusLabel(for: .oneMiss), "Don’t miss twice")
        XCTAssertEqual(WorkoutStreak.statusLabel(for: .oneMiss), WorkoutStreak.missTwiceTitle)
        XCTAssertEqual(WorkoutStreak.statusLabel(for: .twoMiss), "Missed twice")

        // The card is count + status only; the explanatory bodies stay in the
        // notification and the quote cycle, never on the streak card.
        for miss in [WorkoutStreak.MissState.approaching, .oneMiss, .twoMiss] {
            let label = WorkoutStreak.statusLabel(for: miss) ?? ""
            XCTAssertLessThanOrEqual(label.count, 20, label)
            XCTAssertFalse(label.contains("every other day"), label)
            XCTAssertFalse(label.contains("chain"), label)
            XCTAssertNotEqual(label, WorkoutStreak.missTwiceBody)
        }
    }

    func testNotificationBodyIsUnchangedByTheCardCleanup() {
        XCTAssertEqual(WorkoutStreak.missTwiceTitle, "Don’t miss twice")
        XCTAssertEqual(
            WorkoutStreak.missTwiceBody,
            "One miss is alright, but try not to miss twice. Consistency is what matters the most. Keep going."
        )
    }

    func testQuoteRotatesByDayAndTap() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!
        XCTAssertEqual(MotivationalQuotes.dailyIndex(on: day1, calendar: calendar), 0)
        XCTAssertEqual(MotivationalQuotes.dailyIndex(on: day2, calendar: calendar), 1)

        let first = MotivationalQuotes.quote(dayIndex: 0, tapOffset: 0)
        let next = MotivationalQuotes.quote(dayIndex: 0, tapOffset: 1)
        XCTAssertEqual(first.text, "Show up. Log it. Move on.")
        XCTAssertNil(first.attribution)
        XCTAssertEqual(next.text, "Calm mornings are the win.")
        XCTAssertEqual(MotivationalQuotes.quote(dayIndex: 0, tapOffset: 10).text, first.text)
        XCTAssertEqual(MotivationalQuotes.all.count, 10)
        XCTAssertEqual(MotivationalQuotes.all.map(\.attribution), [
            nil,
            nil,
            "Japanese proverb",
            nil,
            nil,
            nil,
            nil,
            nil,
            nil,
            "Inspired by Atomic Habits"
        ])
        XCTAssertTrue(MotivationalQuotes.all.allSatisfy { quote in
            quote.text.count < 160
                && quote.attribution != "R3hab"
        })
    }
}
