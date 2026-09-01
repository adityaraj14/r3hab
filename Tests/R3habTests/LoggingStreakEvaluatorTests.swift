import XCTest
@testable import R3hab

final class LoggingStreakEvaluatorTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func day(_ offset: Int, from today: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: today))!
    }

    private func snap(
        dayOffset: Int,
        from today: Date,
        am: Int? = nil,
        pm: Int? = nil,
        steps: Int? = nil
    ) -> DailyCheckInSnapshot {
        DailyCheckInSnapshot(
            date: day(dayOffset, from: today),
            restingPainAM: am,
            dailyPainPM: pm,
            steps: steps
        )
    }

    func testStreakCountsConsecutiveLoggedDays() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let checkIns = [
            snap(dayOffset: -2, from: today, am: 2),
            snap(dayOffset: -1, from: today, pm: 3),
            snap(dayOffset: 0, from: today, steps: 5000)
        ]

        XCTAssertEqual(
            LoggingStreakEvaluator.streak(endingAt: today, checkIns: checkIns, calendar: calendar),
            3
        )
    }

    func testStreakBreaksOnGap() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let checkIns = [
            snap(dayOffset: -3, from: today, am: 2),
            snap(dayOffset: -1, from: today, pm: 3),
            snap(dayOffset: 0, from: today, am: 1)
        ]

        XCTAssertEqual(
            LoggingStreakEvaluator.streak(endingAt: today, checkIns: checkIns, calendar: calendar),
            2
        )
    }

    func testDisplayStreakUsesTodayWhenLogged() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let checkIns = [
            snap(dayOffset: -1, from: today, am: 2),
            snap(dayOffset: 0, from: today, pm: 3)
        ]

        let result = LoggingStreakEvaluator.displayStreak(
            checkIns: checkIns,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.loggedToday)
    }

    func testDisplayStreakFallsBackToYesterday() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let checkIns = [
            snap(dayOffset: -2, from: today, am: 2),
            snap(dayOffset: -1, from: today, pm: 3)
        ]

        let result = LoggingStreakEvaluator.displayStreak(
            checkIns: checkIns,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(result.count, 2)
        XCTAssertFalse(result.loggedToday)
    }

    func testRewardSameDayBonusWhenAlreadyLogged() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let checkIns = [
            snap(dayOffset: -1, from: today, am: 2),
            snap(dayOffset: 0, from: today, am: 1, pm: 3)
        ]

        let reward = LoggingStreakEvaluator.reward(
            savedDay: today,
            focus: .evening,
            checkIns: checkIns,
            wasAlreadyLoggedToday: true,
            calendar: calendar
        )
        XCTAssertEqual(reward.kind, .sameDayBonus)
        XCTAssertEqual(reward.streak, 2)
    }

    func testRewardStreakStartedOnFirstDay() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let checkIns = [snap(dayOffset: 0, from: today, am: 2)]

        let reward = LoggingStreakEvaluator.reward(
            savedDay: today,
            focus: .morning,
            checkIns: checkIns,
            wasAlreadyLoggedToday: false,
            calendar: calendar
        )
        XCTAssertEqual(reward.kind, .streakStarted)
        XCTAssertEqual(reward.streak, 1)
    }
}
