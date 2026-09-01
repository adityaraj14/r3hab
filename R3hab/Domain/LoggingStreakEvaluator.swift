import Foundation

/// Positive reinforcement after each daily log — consecutive calendar days with any check-in.
struct LogReward: Equatable, Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        case streakStarted
        case streakContinued
        case sameDayBonus
    }

    var id: UUID
    var streak: Int
    var kind: Kind
    var focus: DailyCheckInFocus

    init(streak: Int, kind: Kind, focus: DailyCheckInFocus) {
        self.id = UUID()
        self.streak = streak
        self.kind = kind
        self.focus = focus
    }

    var title: String {
        switch kind {
        case .streakStarted:
            return "Day 1 — you showed up"
        case .streakContinued:
            return streak == 1 ? "Logged!" : "\(streak)-day streak!"
        case .sameDayBonus:
            return "Nice — logged again"
        }
    }

    var message: String {
        switch kind {
        case .streakStarted:
            return focusRewardLine + " Every log is a vote for informed rehab. Keep showing up."
        case .streakContinued:
            return focusRewardLine + " " + streakMessage
        case .sameDayBonus:
            return focusRewardLine + " Each entry makes your trend clearer — that’s the habit."
        }
    }

    private var focusRewardLine: String {
        switch focus {
        case .morning:
            return "Morning pain recorded."
        case .evening:
            return "Evening check-in saved."
        case .full:
            return "Check-in saved."
        }
    }

    private var streakMessage: String {
        switch streak {
        case 1:
            return "One day at a time — that’s how rehab sticks."
        case 2...3:
            return "Small streak, real momentum. Consistency beats intensity."
        case 4...6:
            return "Your logging habit is taking shape. Keep the votes coming."
        case 7...13:
            return "A full week-plus of showing up. This is process in action."
        default:
            return "This is who you are now — someone who judges load by the next morning."
        }
    }
}

enum LoggingStreakEvaluator {
    /// Consecutive logged calendar days ending at `anchor` (inclusive when that day is logged).
    static func streak(
        endingAt anchor: Date,
        checkIns: [DailyCheckInSnapshot],
        calendar: Calendar = .current
    ) -> Int {
        let anchorDay = calendar.startOfDay(for: anchor)
        let byDay = indexByDay(checkIns, calendar: calendar)

        var count = 0
        var cursor = anchorDay
        while true {
            let key = CalendarDay.dayKey(cursor, calendar: calendar)
            guard let row = byDay[key], row.hasLogged else { break }
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// Streak for the landing screen: today if logged, otherwise yesterday’s chain.
    static func displayStreak(
        checkIns: [DailyCheckInSnapshot],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> (count: Int, loggedToday: Bool) {
        let todayStart = calendar.startOfDay(for: today)
        let byDay = indexByDay(checkIns, calendar: calendar)
        let todayKey = CalendarDay.dayKey(todayStart, calendar: calendar)
        let loggedToday = byDay[todayKey]?.hasLogged ?? false

        if loggedToday {
            return (streak(endingAt: todayStart, checkIns: checkIns, calendar: calendar), true)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) {
            return (streak(endingAt: yesterday, checkIns: checkIns, calendar: calendar), false)
        }
        return (0, false)
    }

    static func reward(
        savedDay: Date,
        focus: DailyCheckInFocus,
        checkIns: [DailyCheckInSnapshot],
        wasAlreadyLoggedToday: Bool,
        calendar: Calendar = .current
    ) -> LogReward {
        let count = streak(endingAt: savedDay, checkIns: checkIns, calendar: calendar)
        let kind: LogReward.Kind
        if wasAlreadyLoggedToday {
            kind = .sameDayBonus
        } else if count == 1 {
            kind = .streakStarted
        } else {
            kind = .streakContinued
        }
        return LogReward(streak: count, kind: kind, focus: focus)
    }

    private static func indexByDay(
        _ checkIns: [DailyCheckInSnapshot],
        calendar: Calendar
    ) -> [String: DailyCheckInSnapshot] {
        var byDay: [String: DailyCheckInSnapshot] = [:]
        for checkIn in checkIns {
            byDay[CalendarDay.dayKey(checkIn.date, calendar: calendar)] = checkIn
        }
        return byDay
    }
}

extension DailyCheckInSnapshot {
    var hasLogged: Bool {
        restingPainAM != nil || dailyPainPM != nil || steps != nil
    }
}
