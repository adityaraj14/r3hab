import Foundation

enum SessionSpacing {
    /// Recovery spacing hint: warn when a new hard session lands sooner than this
    /// after the last one. Clock-based on purpose — it protects the tendon, not the chain.
    static let hardGapHours: Double = 48
    static var hardGap: TimeInterval { hardGapHours * 3600 }

    /// Chain cadence in local calendar days. A hard session on day D makes the
    /// next one due on D + 2, and the *whole* of that due day counts — 7 AM on
    /// Monday then 5 PM on Wednesday is a kept chain even though the clock gap
    /// is 58 hours. Only once the due day has ended with no hard session is it a miss.
    static let hardCadenceDays: Int = 2

    /// Whole local calendar days from `from` to `to` (both snapped to start of day).
    static func calendarDays(from: Date, to: Date, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    static func isHard(_ type: SessionType) -> Bool {
        switch type {
        case .isometrics, .hsrStrength, .energyStorage, .tennisSport:
            return true
        case .other:
            return false
        }
    }

    /// Hours since last hard session before `now` (excluding optional id).
    static func hoursSinceLastHard(
        sessions: [TrainingSessionSnapshot],
        now: Date,
        excluding id: UUID? = nil
    ) -> Double? {
        let hard = SessionDraft.finalized(sessions)
            .filter { isHard($0.sessionType) }
            .filter { id == nil || $0.id != id }
            .sorted { $0.date > $1.date || ($0.date == $1.date && $0.createdAt > $1.createdAt) }
        guard let last = hard.first else { return nil }
        // Approximate "session moment" as end of session day for spacing, using createdAt if same day
        let lastMoment = last.createdAt
        return now.timeIntervalSince(lastMoment) / 3600.0
    }

    static func shouldWarnUnder48h(
        sessions: [TrainingSessionSnapshot],
        newType: SessionType,
        now: Date,
        excluding id: UUID? = nil
    ) -> Bool {
        guard isHard(newType) else { return false }
        guard let hours = hoursSinceLastHard(sessions: sessions, now: now, excluding: id) else {
            return false
        }
        return hours < hardGapHours
    }
}
