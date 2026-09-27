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
    /// The load lane plots `loadLbs` and `repLabel` instead.
    var volume: Double?
    /// Top work-set weight in lb for the session logged that day. Nil on rest days,
    /// walk-only days, and any day with no weighted session. Not carried forward.
    var loadLbs: Double? = nil
    /// Working sets × reps for that same session, e.g. "3×8" or "8/8/6".
    /// Warm-ups are already excluded. Nil when no work set recorded reps.
    var repLabel: String? = nil
    /// Check-in step count. Nil when that day was not logged.
    /// A logged zero on a past day stays zero. Zero on the current day is not logged yet.
    var steps: Double? = nil

    var hasValues: Bool {
        pain != nil || duringPain != nil || afterPain != nil || volume != nil || steps != nil
            || loadLbs != nil || repLabel != nil
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

/// Scrub line for the three Progress charts.
/// "Pain 2 · 3×8 @ 45 lb · 6,200 steps". A day with no weighted session says "no session".
enum LaneScrubReadout {
    static let noSession = "no session"

    static func line(point: DayExplorePoint) -> String {
        line(pain: point.pain, repLabel: point.repLabel, loadLbs: point.loadLbs, steps: point.steps)
    }

    static func line(pain: Double?, repLabel: String?, loadLbs: Double?, steps: Double?) -> String {
        var parts: [String] = []
        if let pain {
            parts.append("Pain \(formatPain(pain))")
        }
        parts.append(loadPhrase(repLabel: repLabel, loadLbs: loadLbs) ?? noSession)
        if let steps {
            parts.append("\(formatSteps(steps)) steps")
        }
        return parts.joined(separator: " · ")
    }

    static func loadPhrase(repLabel: String?, loadLbs: Double?) -> String? {
        switch (repLabel, loadLbs) {
        case let (label?, load?):
            return "\(label) @ \(formatLoad(load)) lb"
        case let (nil, load?):
            return "\(formatLoad(load)) lb"
        case let (label?, nil):
            return label
        case (nil, nil):
            return nil
        }
    }

    static func formatPain(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.001 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    static func formatLoad(_ lbs: Double) -> String {
        LoadCopy.formatted(lbs)
    }

    static func formatSteps(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: Int(value.rounded()))) ?? String(Int(value.rounded()))
    }
}

/// Working-set dose for the load lane. Warm-ups are ignored.
/// An left/right pair is one set, matching the prescription model.
enum WorkingSetReps {
    /// "3×8" when every work set has the same reps. "8/8/6" when they differ.
    /// Nil when no work set recorded a rep count (walks, hold-only rows).
    static func label(sets: [ResistanceSet]) -> String? {
        let pairs = SessionSummary.groupWorkSets(sets.filter { !$0.isWarmup })
        let reps = pairs.compactMap { pair -> Int? in
            if let reps = pair.reps { return reps }
            return pair.right?.reps
        }
        return label(reps: reps)
    }

    static func label(reps: [Int]) -> String? {
        guard let first = reps.first else { return nil }
        if reps.allSatisfy({ $0 == first }) {
            return "\(reps.count)×\(first)"
        }
        return reps.map(String.init).joined(separator: "/")
    }

    /// Top work-set weight. Warm-ups and non-positive loads are ignored.
    static func topLoad(sets: [ResistanceSet]) -> Double? {
        let loads = sets.filter { !$0.isWarmup }.compactMap(\.loadLbs).filter { $0 > 0 }
        return loads.max()
    }
}

/// Point captions collide once a day is only a few points wide.
/// The scrub line still reads every session's reps.
enum RepLabelVisibility {
    /// Day indexes whose session point should show a sets × reps caption.
    static func shown(sessionDayIndexes: [Int], dayCount: Int) -> Set<Int> {
        guard let gap = minimumIndexGap(dayCount: dayCount) else { return [] }
        var shown: [Int] = []
        var last: Int?
        for index in sessionDayIndexes.sorted() {
            if let last, index - last < gap { continue }
            shown.append(index)
            last = index
        }
        return Set(shown)
    }

    /// Nil hides every caption. 7-day windows show each session.
    /// 28-day windows keep about one caption every four days.
    static func minimumIndexGap(dayCount: Int) -> Int? {
        if dayCount <= 10 { return 1 }
        if dayCount <= 45 { return 4 }
        return nil
    }
}

/// One logged sample on a continuous chart line.
struct ExploreSample: Equatable, Sendable, Identifiable {
    var date: Date
    var value: Double
    var id: Date { date }
}

/// Accessibility ids for the Progress charts. The container uses
/// `.accessibilityElement(children: .contain)` so the scrubber and readout
/// stay reachable under `chart`.
enum ProgressChartAccessibility {
    static let chart = "progress-explore-chart"
    static let scrubber = "progress-day-scrubber"
    static let readout = "progress-lane-readout"
    static let containedIdentifiers = [scrubber, readout]
}

/// Date axis for the three Progress charts. Labels are the same instants as the
/// plotted days, and only dates whose full "Sep 17" fits in the plot are used.
/// Swift Charts replaces a clipped axis label with "…", so the chart draws these
/// itself instead of asking for an automatic stride.
enum ExploreAxisLayout {
    static let proMaxLogicalWidth: Double = 440
    static let screenHorizontalPadding: Double = 32
    static let sectionCardPadding: Double = 32
    static let chartCardPadding: Double = 20
    static let yAxisWidth: Double = 44
    static let plotTrailingPadding: Double = 4
    /// "Sep 17" in the axis font, with air so two labels never touch.
    static let dateLabelWidth: Double = 56

    static var proMaxPlotWidth: Double {
        plotWidth(screenWidth: proMaxLogicalWidth)
    }

    static func plotWidth(screenWidth: Double) -> Double {
        max(
            1,
            screenWidth
                - screenHorizontalPadding
                - sectionCardPadding
                - chartCardPadding
                - yAxisWidth
                - plotTrailingPadding
        )
    }

    static func xDomain(
        points: [DayExplorePoint],
        plotWidth: Double,
        visibleDayCount: Int,
        labelWidth: Double = dateLabelWidth
    ) -> ClosedRange<Date> {
        guard let first = points.first?.date, let last = points.last?.date else {
            let epoch = Date(timeIntervalSinceReferenceDate: 0)
            return epoch...epoch
        }
        let span = last.timeIntervalSince(first)
        let scrolls = points.count > max(visibleDayCount, 1)
        if scrolls || span <= 0 {
            let pad: TimeInterval = 12 * 60 * 60
            return first.addingTimeInterval(-pad)...last.addingTimeInterval(pad)
        }
        let pad = edgePadding(span: span, plotWidth: plotWidth, labelWidth: labelWidth)
        return first.addingTimeInterval(-pad)...last.addingTimeInterval(pad)
    }

    /// Plotted days to mark. On a fully visible range every returned date fits.
    /// On a scrolling range the dates are spaced for the viewport; the chart
    /// hides any label that would clip the current window.
    static func axisDates(
        points: [DayExplorePoint],
        plotWidth: Double,
        visibleDayCount: Int,
        labelWidth: Double = dateLabelWidth
    ) -> [Date] {
        guard plotWidth > 0, labelWidth > 0 else { return [] }
        let domain = xDomain(
            points: points,
            plotWidth: plotWidth,
            visibleDayCount: visibleDayCount,
            labelWidth: labelWidth
        )
        let scrolls = points.count > max(visibleDayCount, 1)
        let visibleSpan = Double(max(visibleDayCount, 1)) * 24 * 60 * 60
        let minTimeGap = (labelWidth / plotWidth) * visibleSpan
        var chosen: [Date] = []
        for point in points {
            let date = point.date
            if scrolls {
                if let last = chosen.last, date.timeIntervalSince(last) < minTimeGap {
                    continue
                }
                chosen.append(date)
            } else {
                guard labelFits(
                    date: date,
                    domain: domain,
                    plotWidth: plotWidth,
                    labelWidth: labelWidth
                ) else { continue }
                if let last = chosen.last {
                    let dx = labelCenterX(for: date, domain: domain, plotWidth: plotWidth)
                        - labelCenterX(for: last, domain: domain, plotWidth: plotWidth)
                    if dx < labelWidth { continue }
                }
                chosen.append(date)
            }
        }
        return chosen
    }

    static func labelCenterX(
        for date: Date,
        domain: ClosedRange<Date>,
        plotWidth: Double
    ) -> Double {
        let span = domain.upperBound.timeIntervalSince(domain.lowerBound)
        guard span > 0, plotWidth > 0 else { return plotWidth / 2 }
        let t = date.timeIntervalSince(domain.lowerBound) / span
        return t * plotWidth
    }

    static func labelFits(
        date: Date,
        domain: ClosedRange<Date>,
        plotWidth: Double,
        labelWidth: Double = dateLabelWidth
    ) -> Bool {
        let x = labelCenterX(for: date, domain: domain, plotWidth: plotWidth)
        let half = labelWidth / 2
        return x - half >= -0.5 && x + half <= plotWidth + 0.5
    }

    /// Candidates whose labels sit fully inside a viewport. A date on the edge
    /// is dropped so the axis never shows a clipped label.
    static func visibleAxisDates(
        candidates: [Date],
        visibleStart: Date,
        visibleEnd: Date,
        plotWidth: Double,
        labelWidth: Double = dateLabelWidth
    ) -> [Date] {
        let span = visibleEnd.timeIntervalSince(visibleStart)
        guard span > 0, plotWidth > 0 else { return [] }
        let domain = visibleStart...visibleEnd
        return candidates.filter { date in
            labelFits(date: date, domain: domain, plotWidth: plotWidth, labelWidth: labelWidth)
        }
    }

    private static func edgePadding(span: TimeInterval, plotWidth: Double, labelWidth: Double) -> TimeInterval {
        let half = labelWidth / 2 + 1
        let usable = plotWidth - 2 * half
        guard usable > 1, span > 0 else { return 12 * 60 * 60 }
        return span * half / usable
    }
}

/// Splits a series so a missing day does not become an interpolated zero.
enum ExploreSeries {
    /// Logged samples in calendar order. A chart draws one line through these,
    /// so a missing day is a straight span and not a filled-in value.
    static func continuousSamples(
        _ points: [DayExplorePoint],
        value: (DayExplorePoint) -> Double?
    ) -> [ExploreSample] {
        points.compactMap { point in
            guard let sample = value(point) else { return nil }
            return ExploreSample(date: point.date, value: sample)
        }
    }

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
    /// Top work-set weight in lb. Independent of volume, so a load-only row still plots.
    /// Nil for walks and any session with no positive work-set weight.
    var loadLbs: Double? = nil
    /// Sets × reps caption for this session. Nil when reps were not logged.
    var repLabel: String? = nil
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

    /// Steps drawn on the chart and read in the scrub line.
    /// A logged zero on a past day stays zero. Zero today is still empty (Health has not filled in).
    static func chartSteps(
        _ steps: Int?,
        on date: Date,
        today: Date,
        calendar: Calendar
    ) -> Double? {
        guard let steps else { return nil }
        if steps == 0, calendar.isDate(date, inSameDayAs: today) {
            return nil
        }
        return Double(steps)
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
        let load = sessionLoadByDay(
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
                    repLabel: load.labels[key],
                    // Same check-in row the evening editor fills from HealthKit.
                    // Nil = not logged. Today's 0 is treated as not logged yet.
                    steps: chartSteps(row?.steps, on: day, today: startToday, calendar: calendar)
                )
            )
        }
        return result
    }

    /// One load per day that logged a weight. Latest session that day wins;
    /// a tie keeps the heavier top weight and that session's rep label.
    /// Rest days, walks, and days outside the window stay empty — nothing is carried forward.
    static func sessionLoadByDay(
        sessions: [SessionLoadSnapshot],
        dayCount: Int,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> (lbs: [String: Double], labels: [String: String]) {
        let startToday = calendar.startOfDay(for: today)
        var window = Set<String>()
        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: startToday) else { continue }
            window.insert(CalendarDay.dayKey(day, calendar: calendar))
        }

        var logged: [String: LoggedLoad] = [:]
        for session in sessions {
            let key = CalendarDay.dayKey(session.date, calendar: calendar)
            guard window.contains(key), let load = session.loadLbs else { continue }
            let candidate = LoggedLoad(
                createdAt: session.createdAt,
                load: load,
                repLabel: session.repLabel
            )
            logged[key] = preferred(logged[key], candidate)
        }

        var lbs: [String: Double] = [:]
        var labels: [String: String] = [:]
        for (key, row) in logged {
            lbs[key] = row.load
            if let label = row.repLabel {
                labels[key] = label
            }
        }
        return (lbs, labels)
    }

    private struct LoggedLoad {
        var createdAt: Date
        var load: Double
        var repLabel: String?
    }

    private static func preferred(_ existing: LoggedLoad?, _ candidate: LoggedLoad) -> LoggedLoad {
        guard let existing else { return candidate }
        if candidate.createdAt > existing.createdAt { return candidate }
        if candidate.createdAt == existing.createdAt, candidate.load > existing.load { return candidate }
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
