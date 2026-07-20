import Foundation

struct PhaseAExitStatus: Equatable, Sendable {
    var stableDaysCount: Int
    var stableDaysRequired: Int
    var nearNormalStepDaysInStreak: Int
    var needsNearNormalSteps: Bool
    var isReadyToAdvance: Bool
    var message: String
}

enum PhaseAExitEvaluator {
    /// KD-17: AND only; consecutive calendar days; missing day / nil AM breaks streak.
    static func evaluate(
        checkIns: [DailyCheckInSnapshot],
        settings: PhaseSettingsSnapshot,
        today: Date,
        calendar: Calendar = .current
    ) -> PhaseAExitStatus {
        let required = settings.phaseAStableDaysRequired
        let painMax = settings.phaseAPainThreshold
        let stepMin = settings.stepNearNormalMin

        var byDay: [String: DailyCheckInSnapshot] = [:]
        for c in checkIns {
            let key = CalendarDay.dayKey(c.date, calendar: calendar)
            byDay[key] = c
        }

        let todayStart = CalendarDay.startOfDay(today, calendar: calendar)
        let todayKey = CalendarDay.dayKey(todayStart, calendar: calendar)
        let anchor: Date
        if byDay[todayKey] != nil {
            anchor = todayStart
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) {
            anchor = yesterday
        } else {
            anchor = todayStart
        }

        var stable = 0
        var nearNormal = 0
        var cursor = anchor

        for _ in 0..<60 {
            let key = CalendarDay.dayKey(cursor, calendar: calendar)
            guard let row = byDay[key] else { break }
            guard let am = row.restingPainAM else { break }
            if am > painMax { break }
            stable += 1
            if let steps = row.steps, steps >= stepMin {
                nearNormal += 1
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        let needsSteps = nearNormal == 0
        let ready = stable >= required && !needsSteps
        let message: String
        if ready {
            message = "Exit criteria looking good — switch to Phase B when ready (Settings)"
        } else if stable >= required && needsSteps {
            message = "\(stable)/\(required) stable · steps still low — aim ~6–8k when pain stays ≤\(painMax)"
        } else {
            let stepHint = needsSteps ? " · Need a ~\(stepMin / 1000)k+ step day in the streak" : ""
            message = "Stable mornings: \(stable)/\(required)\(stepHint)"
        }

        return PhaseAExitStatus(
            stableDaysCount: stable,
            stableDaysRequired: required,
            nearNormalStepDaysInStreak: nearNormal,
            needsNearNormalSteps: needsSteps,
            isReadyToAdvance: ready,
            message: message
        )
    }
}
