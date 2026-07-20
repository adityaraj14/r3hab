import Foundation

enum SessionSpacing {
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
        let hard = sessions
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
        return hours < 48
    }
}
