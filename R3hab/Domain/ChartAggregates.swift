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
            case .dailyPM, .lowerBackAM, .lowerBackPM:
                // DailyCheckInSnapshot only has resting + steps; need extended snapshot or pass full models
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
        case lowerBackAM
        case lowerBackPM
        case steps
    }
}

/// Full check-in fields for charts (knee + lower back AM/PM/steps).
struct DailyMetricSnapshot: Equatable, Sendable {
    var date: Date
    var restingPainAM: Int?
    var dailyPainPM: Int?
    var lowerBackPainAM: Int?
    var lowerBackPainPM: Int?
    var steps: Int?
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
            case .lowerBackAM: value = row?.lowerBackPainAM.map(Double.init)
            case .lowerBackPM: value = row?.lowerBackPainPM.map(Double.init)
            case .steps: value = row?.steps.map(Double.init)
            }
            result.append(DayValue(dayKey: key, date: day, value: value))
        }
        return result
    }

    static func average(of series: [DayValue]) -> Double? {
        let vals = series.compactMap(\.value)
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }
}
