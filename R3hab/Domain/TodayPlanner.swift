import Foundation

/// The one bright action on Today. Everything else on the screen is quiet.
enum TodayNextAction: Equatable, Sendable {
    /// Oldest overdue 24h item. `remaining` counts the others still waiting.
    case resolvePending(sessionID: UUID, remaining: Int)
    case logMorning
    /// Most recent session (within the after-pain window) with no after score.
    case logAfterPain(sessionID: UUID)
    case logSession
    case logEvening
    /// Morning, session (or evening), and evening are in. Nothing to push.
    case allDone
}

/// Pure inputs so the pick is unit-testable without SwiftData.
struct TodayPlannerInput: Equatable, Sendable {
    var hasMorningPain: Bool
    var hasEveningPain: Bool
    /// Oldest first — the order `PendingQueue.overdue` already produces.
    var overduePending: [UUID] = []
    /// Newest first. Only sessions inside `TodayPlanner.afterPainWindowHours`.
    var missingAfterPain: [UUID] = []
    var trainedToday: Bool
    var isEvening: Bool
}

enum TodayPlanner {
    /// After this many hours an unlogged after-pain stops being “next up”.
    /// It stays reachable from History (swipe → After).
    static let afterPainWindowHours: Double = 48

    /// Priority: the forced 24h loop first, then the morning score (it is the
    /// protocol’s judge), then a fresh after-pain, then the day’s one load
    /// (evening pain wins once the evening reminder hour has passed).
    static func nextAction(_ input: TodayPlannerInput) -> TodayNextAction {
        if let first = input.overduePending.first {
            return .resolvePending(sessionID: first, remaining: input.overduePending.count - 1)
        }
        if !input.hasMorningPain {
            return .logMorning
        }
        if let session = input.missingAfterPain.first {
            return .logAfterPain(sessionID: session)
        }
        if input.isEvening, !input.hasEveningPain {
            return .logEvening
        }
        if !input.trainedToday {
            return .logSession
        }
        if !input.hasEveningPain {
            return .logEvening
        }
        return .allDone
    }

    /// Evening starts at the PM reminder time (default 18:30).
    static func isEvening(
        now: Date,
        pmReminderHour: Int,
        pmReminderMinute: Int,
        calendar: Calendar = .current
    ) -> Bool {
        let comps = calendar.dateComponents([.hour, .minute], from: now)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return minutes >= pmReminderHour * 60 + pmReminderMinute
    }

    /// Sessions still worth pushing for an after score, newest first.
    static func recentMissingAfterPain(
        sessions: [TrainingSessionSnapshot],
        now: Date
    ) -> [UUID] {
        sessions
            .filter { !$0.hasLoggedPainAfter }
            .filter { now.timeIntervalSince($0.createdAt) <= afterPainWindowHours * 3600 }
            .sorted { $0.createdAt > $1.createdAt }
            .map(\.id)
    }

    static func trainedToday(
        sessions: [TrainingSessionSnapshot],
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        sessions.contains { calendar.isDate($0.date, inSameDayAs: now) }
    }
}
