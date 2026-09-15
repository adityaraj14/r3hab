import Foundation

struct DayValue: Identifiable, Equatable, Sendable {
    var id: String { dayKey }
    var dayKey: String
    var date: Date
    var value: Double?
}

enum ChartAggregates {
    /// Build last `dayCount` calendar days ending at `today`, filling gaps with nil.
    static func series(
        checkIns: [DailyCheckInSnapshot],
        metric: Metric,
        dayCount: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [DayValue] {
        let startToday = calendar.startOfDay(for: today)
        var byDay: [String: DailyCheckInSnapshot] = [:]
        for c in checkIns {
            byDay[CalendarDay.dayKey(c.date, calendar: calendar)] = c
        }

        var result: [DayValue] = []
        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startToday) else { continue }
            let key = CalendarDay.dayKey(day, calendar: calendar)
            let row = byDay[key]
            let value: Double?
            switch metric {
            case .restingAM:
                value = row?.restingPainAM.map(Double.init)
            case .dailyPM:
                value = nil
            case .steps:
                value = row?.steps.map(Double.init)
            }
            result.append(DayValue(dayKey: key, date: day, value: value))
        }
        return result
    }

    enum Metric {
        case restingAM
        case dailyPM
        case steps
    }
}

/// Check-in fields for charts (knee AM/PM + steps).
struct DailyMetricSnapshot: Equatable, Sendable {
    var date: Date
    var restingPainAM: Int?
    var dailyPainPM: Int?
    var steps: Int?
}

/// One calendar day for the explorable knee chart.
struct DayExplorePoint: Identifiable, Equatable, Sendable {
    var id: String { dayKey }
    var dayKey: String
    var date: Date
    /// Averaged morning + evening pain (or the one logged side).
    var pain: Double?
    var morningPain: Double? = nil
    var eveningPain: Double? = nil
    var duringPain: Double? = nil
    var afterPain: Double? = nil
    /// Daily session volume (Σ work-set reps × lb). Nil days stay gaps.
    var volume: Double?

    var hasValues: Bool {
        pain != nil || duringPain != nil || afterPain != nil || volume != nil
    }
}

struct SessionPainSnapshot: Equatable, Sendable {
    var date: Date
    var painDuring: Int
    var painAfter: Int
}

struct SessionOutcomeSnapshot: Equatable, Sendable {
    var date: Date
    var createdAt: Date
    var response24h: Response24h
}

struct DayOutcomePoint: Identifiable, Equatable, Sendable {
    var id: String { dayKey }
    var dayKey: String
    var date: Date
    var better: Int
    var same: Int
    var worse: Int
    var pending: Int

    var totalResolved: Int { better + same + worse }
    var hasValues: Bool { better + same + worse + pending > 0 }
}

struct OutcomeMix: Equatable, Sendable {
    var better: Int
    var same: Int
    var worse: Int
    var pending: Int
    var cleanStreak: Int

    var resolved: Int { better + same + worse }
    var clean: Int { better + same }
}

struct ConsistencySummary: Equatable, Sendable {
    var windowDays: Int
    var checkInDays: Int
    var morningDays: Int
    var sessionDays: Int
    var sessionCount: Int

    var checkInRate: Double {
        windowDays == 0 ? 0 : Double(checkInDays) / Double(windowDays)
    }
}

/// Maps a plot-x tap onto the nearest day. Used by KneeExploreChart so 7- and 28-day
/// ranges share the same selection math (and so tests can lock the 28-day path).
enum ChartDaySelection {
    static func nearestPoint(to date: Date, in points: [DayExplorePoint]) -> DayExplorePoint? {
        points.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }

    /// Linear map of `x` in a plot of `width` onto the date span of `points`.
    static func point(atPlotX x: Double, width: Double, points: [DayExplorePoint]) -> DayExplorePoint? {
        guard !points.isEmpty else { return nil }
        guard width > 0, points.count > 1 else { return points[0] }
        let first = points[0].date.timeIntervalSinceReferenceDate
        let last = points[points.count - 1].date.timeIntervalSinceReferenceDate
        let span = last - first
        guard span > 0 else { return points[0] }
        let t = max(0, min(1, x / width))
        let target = Date(timeIntervalSinceReferenceDate: first + t * span)
        return nearestPoint(to: target, in: points)
    }
}

/// Session work-set volume for Progress charts.
struct SessionLoadSnapshot: Equatable, Sendable {
    var date: Date
    /// Σ reps × lb for work sets. Nil when volume cannot be derived.
    var volume: Double?
}

enum ChartMetricBuilder {
    static func series(
        rows: [DailyMetricSnapshot],
        metric: ChartAggregates.Metric,
        dayCount: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [DayValue] {
        let startToday = calendar.startOfDay(for: today)
        var byDay: [String: DailyMetricSnapshot] = [:]
        for r in rows {
            byDay[CalendarDay.dayKey(r.date, calendar: calendar)] = r
        }
        var result: [DayValue] = []
        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startToday) else { continue }
            let key = CalendarDay.dayKey(day, calendar: calendar)
            let row = byDay[key]
            let value: Double?
            switch metric {
            case .restingAM: value = row?.restingPainAM.map(Double.init)
            case .dailyPM: value = row?.dailyPainPM.map(Double.init)
            case .steps: value = row?.steps.map(Double.init)
            }
            result.append(DayValue(dayKey: key, date: day, value: value))
        }
        return result
    }

    /// Daily **volume** (sum of session volumes) for resistance sessions.
    static func volumeSeries(
        sessions: [SessionLoadSnapshot],
        dayCount: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [DayValue] {
        let startToday = calendar.startOfDay(for: today)
        var volByDay: [String: Double] = [:]
        for s in sessions {
            let key = CalendarDay.dayKey(s.date, calendar: calendar)
            guard let v = s.volume, v > 0 else { continue }
            volByDay[key, default: 0] += v
        }

        var result: [DayValue] = []
        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startToday) else { continue }
            let key = CalendarDay.dayKey(day, calendar: calendar)
            result.append(DayValue(dayKey: key, date: day, value: volByDay[key]))
        }
        return result
    }

    static func explorePoints(
        checkIns: [DailyMetricSnapshot],
        sessions: [SessionLoadSnapshot],
        dayCount: Int,
        today: Date = Date(),
        calendar: Calendar = .current,
        sessionPains: [SessionPainSnapshot] = []
    ) -> [DayExplorePoint] {
        let startToday = calendar.startOfDay(for: today)
        var painByDay: [String: DailyMetricSnapshot] = [:]
        for row in checkIns {
            painByDay[CalendarDay.dayKey(row.date, calendar: calendar)] = row
        }
        var volumeByDay: [String: Double] = [:]
        for point in volumeSeries(
            sessions: sessions,
            dayCount: dayCount,
            today: today,
            calendar: calendar
        ) {
            if let value = point.value {
                volumeByDay[point.dayKey] = value
            }
        }
        var duringByDay: [String: Int] = [:]
        var afterByDay: [String: Int] = [:]
        for session in sessionPains {
            let key = CalendarDay.dayKey(session.date, calendar: calendar)
            duringByDay[key] = max(duringByDay[key] ?? 0, session.painDuring)
            if let after = PainScore.optional(session.painAfter) {
                afterByDay[key] = max(afterByDay[key] ?? 0, after)
            }
        }

        var result: [DayExplorePoint] = []
        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startToday) else { continue }
            let key = CalendarDay.dayKey(day, calendar: calendar)
            let row = painByDay[key]
            result.append(
                DayExplorePoint(
                    dayKey: key,
                    date: day,
                    pain: averagedDailyPain(morning: row?.restingPainAM, evening: row?.dailyPainPM),
                    morningPain: row?.restingPainAM.map(Double.init),
                    eveningPain: row?.dailyPainPM.map(Double.init),
                    duringPain: duringByDay[key].map(Double.init),
                    afterPain: afterByDay[key].map(Double.init),
                    volume: volumeByDay[key]
                )
            )
        }
        return result
    }

    /// Morning + evening mean when both exist; otherwise the logged side. Never invents 0.
    static func averagedDailyPain(morning: Int?, evening: Int?) -> Double? {
        switch (morning, evening) {
        case let (am?, pm?):
            return (Double(am) + Double(pm)) / 2
        case let (am?, nil):
            return Double(am)
        case let (nil, pm?):
            return Double(pm)
        case (nil, nil):
            return nil
        }
    }

    static func average(of series: [DayValue]) -> Double? {
        let vals = series.compactMap(\.value)
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }

    static func outcomePoints(
        sessions: [SessionOutcomeSnapshot],
        dayCount: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [DayOutcomePoint] {
        let startToday = calendar.startOfDay(for: today)
        var byDay: [String: (better: Int, same: Int, worse: Int, pending: Int)] = [:]
        for session in sessions {
            let key = CalendarDay.dayKey(session.date, calendar: calendar)
            var bucket = byDay[key] ?? (0, 0, 0, 0)
            switch session.response24h {
            case .better: bucket.better += 1
            case .same: bucket.same += 1
            case .worse: bucket.worse += 1
            case .pending: bucket.pending += 1
            case .notApplicable: break
            }
            byDay[key] = bucket
        }

        var result: [DayOutcomePoint] = []
        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startToday) else { continue }
            let key = CalendarDay.dayKey(day, calendar: calendar)
            let bucket = byDay[key] ?? (0, 0, 0, 0)
            result.append(
                DayOutcomePoint(
                    dayKey: key,
                    date: day,
                    better: bucket.better,
                    same: bucket.same,
                    worse: bucket.worse,
                    pending: bucket.pending
                )
            )
        }
        return result
    }

    static func outcomeMix(
        sessions: [SessionOutcomeSnapshot],
        dayCount: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> OutcomeMix {
        let points = outcomePoints(
            sessions: sessions,
            dayCount: dayCount,
            today: today,
            calendar: calendar
        )
        return OutcomeMix(
            better: points.reduce(0) { $0 + $1.better },
            same: points.reduce(0) { $0 + $1.same },
            worse: points.reduce(0) { $0 + $1.worse },
            pending: points.reduce(0) { $0 + $1.pending },
            cleanStreak: cleanStreak(sessions: sessions, today: today, calendar: calendar)
        )
    }

    /// Consecutive Better/Same sessions from the most recent resolved (non-rest) session.
    static func cleanStreak(
        sessions: [SessionOutcomeSnapshot],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let startToday = calendar.startOfDay(for: today)
        let resolved = sessions
            .filter { $0.response24h == .better || $0.response24h == .same || $0.response24h == .worse }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date > rhs.date }
                return lhs.createdAt > rhs.createdAt
            }
        var streak = 0
        for session in resolved {
            guard calendar.startOfDay(for: session.date) <= startToday else { continue }
            if session.response24h == .worse { break }
            streak += 1
        }
        return streak
    }

    static func consistency(
        checkIns: [DailyMetricSnapshot],
        sessions: [SessionOutcomeSnapshot],
        dayCount: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> ConsistencySummary {
        let startToday = calendar.startOfDay(for: today)
        var checkInDays = Set<String>()
        var morningDays = Set<String>()
        for row in checkIns {
            let key = CalendarDay.dayKey(row.date, calendar: calendar)
            if row.restingPainAM != nil || row.dailyPainPM != nil || row.steps != nil {
                checkInDays.insert(key)
            }
            if row.restingPainAM != nil {
                morningDays.insert(key)
            }
        }
        var sessionDays = Set<String>()
        for session in sessions {
            sessionDays.insert(CalendarDay.dayKey(session.date, calendar: calendar))
        }

        var windowKeys: [String] = []
        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startToday) else { continue }
            windowKeys.append(CalendarDay.dayKey(day, calendar: calendar))
        }
        let window = Set(windowKeys)
        return ConsistencySummary(
            windowDays: windowKeys.count,
            checkInDays: checkInDays.intersection(window).count,
            morningDays: morningDays.intersection(window).count,
            sessionDays: sessionDays.intersection(window).count,
            sessionCount: sessions.filter {
                window.contains(CalendarDay.dayKey($0.date, calendar: calendar))
            }.count
        )
    }
}
