import Foundation

/// Progress chart window. Default stays 7 days.
enum ProgressDayRange: CaseIterable, Identifiable, Hashable, Sendable {
    case days7
    case days28
    case days90
    case all

    var id: String {
        switch self {
        case .days7: return "7"
        case .days28: return "28"
        case .days90: return "90"
        case .all: return "all"
        }
    }

    var pickerTitle: String {
        switch self {
        case .days7: return "7"
        case .days28: return "28"
        case .days90: return "90"
        case .all: return "All"
        }
    }

    /// All windows longer than this still plot every day, then scroll.
    static let chartViewportCap = 90
    /// All from earliest log through today, but never more than two years of points.
    static let allCapDays = 730

    func dayCount(
        checkInDates: [Date],
        sessionDates: [Date],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        switch self {
        case .days7: return 7
        case .days28: return 28
        case .days90: return 90
        case .all:
            let startToday = calendar.startOfDay(for: today)
            let dates = (checkInDates + sessionDates).map { calendar.startOfDay(for: $0) }
            guard let earliest = dates.min() else { return 7 }
            let span = calendar.dateComponents([.day], from: earliest, to: startToday).day ?? 0
            return min(max(span + 1, 1), Self.allCapDays)
        }
    }

    func chartVisibleDays(windowDays: Int) -> Int {
        min(windowDays, Self.chartViewportCap)
    }
}

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
    /// Daily session volume (Σ work-set reps × lb). The Progress readout uses this.
    /// The chart plots `loadLbs` instead.
    var volume: Double?
    /// Working (top) weight in lb for the primary lift. Nil on walk-only days and
    /// before the first logged load. Rest days copy the previous load.
    var loadLbs: Double? = nil
    /// True when `loadLbs` is carried from the last logged load (a rest day).
    var loadCarried: Bool = false
    /// Check-in step count. Nil when that day was not logged. Zero is a real HealthKit zero.
    var steps: Double? = nil

    var hasValues: Bool {
        pain != nil || duringPain != nil || afterPain != nil || volume != nil || steps != nil
            || (loadLbs != nil && !loadCarried)
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

    /// Inverse of `point(atPlotX:width:points:)`. Endpoints sit on the plot edges.
    static func plotX(for date: Date, in points: [DayExplorePoint], width: Double) -> Double {
        guard width > 0, let first = points.first?.date, let last = points.last?.date else { return 0 }
        let span = last.timeIntervalSince(first)
        guard span > 0 else { return width / 2 }
        let t = date.timeIntervalSince(first) / span
        return min(width, max(0, t * width))
    }

    /// Move `step` days from the nearest point. Clamps at the ends of the series.
    static func neighbor(of date: Date, in points: [DayExplorePoint], step: Int) -> DayExplorePoint? {
        guard let current = nearestPoint(to: date, in: points),
              let index = points.firstIndex(where: { $0.dayKey == current.dayKey }) else {
            return points.first
        }
        let next = index + step
        guard points.indices.contains(next) else { return points[index] }
        return points[next]
    }
}

/// Shared scale for the combined chart. Nil stays a gap. Zero stays zero.
enum ExploreSignalScale {
    static func peak(_ values: [Double?], floor: Double = 1) -> Double {
        let logged = values.compactMap { $0 }
        return max(logged.max() ?? floor, floor)
    }

    static func unit(_ value: Double?, peak: Double) -> Double? {
        guard let value else { return nil }
        guard peak > 0 else { return 0 }
        return min(1, max(0, value / peak))
    }
}

/// Ribbon scrub copy. A metric shows "—" only when that metric is missing.
/// The day placeholder is used only when pain, load, and steps are all absent.
enum RibbonDayReadout {
    static let noData = "No pain, load, or steps"

    static func pain(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value.rounded() == value {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    static func load(_ value: Double?) -> String {
        value.map(LoadCopy.labeled) ?? "—"
    }

    static func steps(_ value: Double?) -> String {
        guard let value else { return "—" }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: Int(value.rounded()))) ?? String(Int(value.rounded()))
    }

    static func hasData(_ point: DayExplorePoint) -> Bool {
        point.pain != nil || point.loadLbs != nil || point.steps != nil
    }

    static func summary(point: DayExplorePoint, date: String) -> String {
        guard hasData(point) else { return "\(date). \(noData)." }
        return "\(date). Pain \(pain(point.pain)). Load \(load(point.loadLbs)). Steps \(steps(point.steps))."
    }
}

/// Days that get a steps point. Missing days are left out so nothing is drawn across the gap.
enum RibbonSeries {
    static func stepDays(_ points: [DayExplorePoint]) -> [DayExplorePoint] {
        points.filter { $0.steps != nil }
    }
}

/// Splits a series so a missing day does not become an interpolated zero.
enum ExploreSeries {
    static func contiguousSegments(
        _ points: [DayExplorePoint],
        value: (DayExplorePoint) -> Double?
    ) -> [[DayExplorePoint]] {
        var segments: [[DayExplorePoint]] = []
        var current: [DayExplorePoint] = []
        for point in points {
            if value(point) != nil {
                current.append(point)
            } else if !current.isEmpty {
                segments.append(current)
                current = []
            }
        }
        if !current.isEmpty {
            segments.append(current)
        }
        return segments
    }
}

/// Session work for Progress charts.
struct SessionLoadSnapshot: Equatable, Sendable {
    var date: Date
    var createdAt: Date = .distantPast
    /// Σ reps × lb for work sets. Nil when volume cannot be derived.
    var volume: Double?
    /// Working (top) weight in lb. Independent of volume, so a load-only row still plots.
    var loadLbs: Double? = nil
    /// Walk-only QL day: steps or time, no weight. Does not inherit a carried load.
    var walkOnly: Bool = false
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
        let load = workingLoadByDay(
            sessions: sessions,
            dayCount: dayCount,
            today: today,
            calendar: calendar
        )
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
                    volume: volumeByDay[key],
                    loadLbs: load.lbs[key],
                    loadCarried: load.carried[key] ?? false,
                    // Same check-in row the evening editor fills from HealthKit. Nil = not logged.
                    steps: row?.steps.map(Double.init)
                )
            )
        }
        return result
    }

    /// Latest session that day wins; a tie keeps the heavier top weight.
    /// Rest days carry the last load. A walk-only day stays empty and does not crash.
    static func workingLoadByDay(
        sessions: [SessionLoadSnapshot],
        dayCount: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> (lbs: [String: Double], carried: [String: Bool]) {
        let startToday = calendar.startOfDay(for: today)
        var windowKeys: [String] = []
        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startToday) else { continue }
            windowKeys.append(CalendarDay.dayKey(day, calendar: calendar))
        }
        let window = Set(windowKeys)

        var logged: [String: (createdAt: Date, load: Double)] = [:]
        var walkDays = Set<String>()
        var seed: (createdAt: Date, load: Double)?
        for session in sessions {
            let key = CalendarDay.dayKey(session.date, calendar: calendar)
            if session.walkOnly, session.loadLbs == nil {
                if window.contains(key) { walkDays.insert(key) }
                continue
            }
            guard let load = session.loadLbs else { continue }
            if window.contains(key) {
                logged[key] = preferred(logged[key], createdAt: session.createdAt, load: load)
            } else if let windowStart = calendar.date(byAdding: .day, value: -(dayCount - 1), to: startToday),
                      calendar.startOfDay(for: session.date) < windowStart {
                seed = preferred(seed, createdAt: session.createdAt, load: load)
            }
        }

        var lbs: [String: Double] = [:]
        var carried: [String: Bool] = [:]
        var last = seed?.load
        for key in windowKeys {
            if let row = logged[key] {
                lbs[key] = row.load
                carried[key] = false
                last = row.load
            } else if walkDays.contains(key) {
                carried[key] = false
            } else if let last {
                lbs[key] = last
                carried[key] = true
            }
        }
        return (lbs, carried)
    }

    private static func preferred(
        _ existing: (createdAt: Date, load: Double)?,
        createdAt: Date,
        load: Double
    ) -> (createdAt: Date, load: Double) {
        guard let existing else { return (createdAt, load) }
        if createdAt > existing.createdAt { return (createdAt, load) }
        if createdAt == existing.createdAt, load > existing.load { return (createdAt, load) }
        return existing
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
