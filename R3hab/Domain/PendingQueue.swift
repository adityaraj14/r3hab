import Foundation

enum PendingQueue {
    /// Overdue priority list: date < startOfToday, still pending, snooze expired or never used.
    static func overdue(
        sessions: [TrainingSessionSnapshot],
        now: Date,
        calendar: Calendar = .current
    ) -> [TrainingSessionSnapshot] {
        let today = CalendarDay.startOfDay(now, calendar: calendar)
        return sessions
            .filter { s in
                guard s.response24h == .pending else { return false }
                guard s.date < today else { return false }
                if let until = s.snoozedUntil, until > now { return false }
                return true
            }
            .sorted { a, b in
                if a.date != b.date { return a.date < b.date }
                return a.createdAt < b.createdAt
            }
    }

    /// Today's pending sessions (early-resolve candidates).
    static func todayPending(
        sessions: [TrainingSessionSnapshot],
        now: Date,
        calendar: Calendar = .current
    ) -> [TrainingSessionSnapshot] {
        let today = CalendarDay.startOfDay(now, calendar: calendar)
        return sessions
            .filter { $0.response24h == .pending && CalendarDay.startOfDay($0.date, calendar: calendar) == today }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Next AM reminder after a reference date (local).
    static func nextMorningReminder(
        after reference: Date,
        amHour: Int,
        amMinute: Int,
        calendar: Calendar = .current
    ) -> Date {
        let start = CalendarDay.startOfDay(reference, calendar: calendar)
        var comps = calendar.dateComponents([.year, .month, .day], from: start)
        comps.hour = amHour
        comps.minute = amMinute
        comps.second = 0
        let todayMorning = calendar.date(from: comps) ?? reference
        if todayMorning > reference {
            return todayMorning
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        var t = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        t.hour = amHour
        t.minute = amMinute
        t.second = 0
        return calendar.date(from: t) ?? tomorrow
    }

    /// Fire time for 24h nag: morning after session.date at AM reminder.
    static func notificationFireDate(
        sessionDate: Date,
        amHour: Int,
        amMinute: Int,
        calendar: Calendar = .current
    ) -> Date {
        let day = CalendarDay.startOfDay(sessionDate, calendar: calendar)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        var comps = calendar.dateComponents([.year, .month, .day], from: nextDay)
        comps.hour = amHour
        comps.minute = amMinute
        comps.second = 0
        return calendar.date(from: comps) ?? nextDay
    }

    static func shouldScheduleNotification(fireAt: Date, now: Date) -> Bool {
        fireAt > now
    }
}
