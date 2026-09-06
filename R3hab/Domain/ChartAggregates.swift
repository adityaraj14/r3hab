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

struct SessionSideLoadSnapshot: Equatable, Sendable {
    var date: Date
    var leftMaxLbs: Double?
    var rightMaxLbs: Double?
    var unspecifiedMaxLbs: Double?
}

/// One calendar day for the explorable knee chart.
struct DayExplorePoint: Identifiable, Equatable, Sendable {
    var id: String { dayKey }
    var dayKey: String
    var date: Date
    var amPain: Double?
    var leftLoadLbs: Double?
    var rightLoadLbs: Double?

    var hasValues: Bool {
        amPain != nil || leftLoadLbs != nil || rightLoadLbs != nil
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

/// Session load point for resistance trend charts.
struct SessionLoadSnapshot: Equatable, Sendable {
    var date: Date
    /// Preferred chart metric: volume (Σ reps × lb) when available.
    var volume: Double?
    /// Max load that session (lb).
    var maxLoadLbs: Double?
    /// Legacy single load.
    var loadLbs: Double?

    init(date: Date, volume: Double? = nil, maxLoadLbs: Double? = nil, loadLbs: Double? = nil) {
        self.date = date
        self.volume = volume
        self.maxLoadLbs = maxLoadLbs
        self.loadLbs = loadLbs
    }
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
            let v = s.volume ?? {
                // Fallback: max load as weak proxy when volume missing
                s.maxLoadLbs ?? s.loadLbs
            }()
            guard let v, v > 0 else { continue }
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

    /// Max load (lb) per calendar day (for legend / secondary).
    static func loadSeries(
        sessions: [SessionLoadSnapshot],
        dayCount: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [DayValue] {
        let startToday = calendar.startOfDay(for: today)
        var maxByDay: [String: Double] = [:]
        for s in sessions {
            guard let load = s.maxLoadLbs ?? s.loadLbs else { continue }
            let key = CalendarDay.dayKey(s.date, calendar: calendar)
            maxByDay[key] = max(maxByDay[key] ?? 0, load)
        }

        var result: [DayValue] = []
        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startToday) else { continue }
            let key = CalendarDay.dayKey(day, calendar: calendar)
            result.append(DayValue(dayKey: key, date: day, value: maxByDay[key]))
        }
        return result
    }

    /// Map volume (or load) onto the 0…10 pain axis so trends can share one chart.
    static func scaledLoadSeries(
        loadPoints: [DayValue],
        painDomainMax: Double = 10
    ) -> (scaled: [DayValue], maxLoad: Double?) {
        let loads = loadPoints.compactMap(\.value)
        guard let maxLoad = loads.max(), maxLoad > 0 else {
            return (
                loadPoints.map { DayValue(dayKey: $0.dayKey, date: $0.date, value: nil) },
                nil
            )
        }
        let scaled = loadPoints.map { point -> DayValue in
            guard let v = point.value else {
                return DayValue(dayKey: point.dayKey, date: point.date, value: nil)
            }
            return DayValue(
                dayKey: point.dayKey,
                date: point.date,
                value: (v / maxLoad) * painDomainMax
            )
        }
        return (scaled, maxLoad)
    }

    static func explorePoints(
        checkIns: [DailyMetricSnapshot],
        sideLoads: [SessionSideLoadSnapshot],
        dayCount: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [DayExplorePoint] {
        let startToday = calendar.startOfDay(for: today)
        var painByDay: [String: DailyMetricSnapshot] = [:]
        for row in checkIns {
            painByDay[CalendarDay.dayKey(row.date, calendar: calendar)] = row
        }
        var leftByDay: [String: Double] = [:]
        var rightByDay: [String: Double] = [:]
        for session in sideLoads {
            let key = CalendarDay.dayKey(session.date, calendar: calendar)
            if let left = session.leftMaxLbs {
                leftByDay[key] = max(leftByDay[key] ?? 0, left)
            }
            if let right = session.rightMaxLbs {
                rightByDay[key] = max(rightByDay[key] ?? 0, right)
            }
            if session.leftMaxLbs == nil, session.rightMaxLbs == nil, let load = session.unspecifiedMaxLbs {
                leftByDay[key] = max(leftByDay[key] ?? 0, load)
                rightByDay[key] = max(rightByDay[key] ?? 0, load)
            }
        }

        var result: [DayExplorePoint] = []
        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startToday) else { continue }
            let key = CalendarDay.dayKey(day, calendar: calendar)
            result.append(
                DayExplorePoint(
                    dayKey: key,
                    date: day,
                    amPain: painByDay[key]?.restingPainAM.map(Double.init),
                    leftLoadLbs: leftByDay[key],
                    rightLoadLbs: rightByDay[key]
                )
            )
        }
        return result
    }

    static func average(of series: [DayValue]) -> Double? {
        let vals = series.compactMap(\.value)
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }
}
