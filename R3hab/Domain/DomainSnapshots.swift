import Foundation

/// Pure value type for domain evaluation (no SwiftData dependency).
struct DailyCheckInSnapshot: Equatable, Sendable {
    var date: Date
    var restingPainAM: Int?
    var steps: Int?
}

struct TrainingSessionSnapshot: Equatable, Sendable {
    var id: UUID
    var date: Date
    var createdAt: Date
    var sessionType: SessionType
    var response24h: Response24h
    var decision: SessionDecision?
    var resolvedAt: Date?
    var snoozedUntil: Date?
    var phase: RehabPhase
    var painDuring: Int
    var painAfter: Int
    var isDraft: Bool

    init(
        id: UUID = UUID(),
        date: Date,
        createdAt: Date,
        sessionType: SessionType,
        response24h: Response24h,
        decision: SessionDecision?,
        resolvedAt: Date?,
        snoozedUntil: Date?,
        phase: RehabPhase,
        painDuring: Int = 0,
        painAfter: Int = PainScore.notLogged,
        isDraft: Bool = false
    ) {
        self.id = id
        self.date = date
        self.createdAt = createdAt
        self.sessionType = sessionType
        self.response24h = response24h
        self.decision = decision
        self.resolvedAt = resolvedAt
        self.snoozedUntil = snoozedUntil
        self.phase = phase
        self.painDuring = painDuring
        self.painAfter = painAfter
        self.isDraft = isDraft
    }

    var hasLoggedPainAfter: Bool {
        PainScore.isLogged(painAfter)
    }

    var isFinalized: Bool { !isDraft }
}

enum SessionDraft {
    static let emptyMessage = "Add a load, a note, or pain during to save a draft."

    static func finalized(_ sessions: [TrainingSessionSnapshot]) -> [TrainingSessionSnapshot] {
        sessions.filter(\.isFinalized)
    }

    static func isWorthSaving(
        painDuring: Int?,
        notes: String,
        sets: [ResistanceSet]
    ) -> Bool {
        if let painDuring, PainScore.isLogged(painDuring) { return true }
        if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return sets.contains { $0.loadLbs != nil }
    }

    static func openDraftID(
        in sessions: [TrainingSessionSnapshot],
        on day: Date,
        preferring type: SessionType,
        calendar: Calendar = .current
    ) -> UUID? {
        let drafts = sessions.filter { $0.isDraft && calendar.isDate($0.date, inSameDayAs: day) }
        if let match = drafts.first(where: { $0.sessionType == type }) {
            return match.id
        }
        return drafts.first?.id
    }
}

struct PhaseSettingsSnapshot: Equatable, Sendable {
    var currentPhase: RehabPhase
    var phaseChangedAt: Date
    var phaseAPainThreshold: Int
    var phaseAStableDaysRequired: Int
    var stepNearNormalMin: Int
    var amReminderHour: Int
    var amReminderMinute: Int

    static let `default` = PhaseSettingsSnapshot(
        currentPhase: .aFlareDeLoad,
        phaseChangedAt: Date(),
        phaseAPainThreshold: 2,
        phaseAStableDaysRequired: 3,
        stepNearNormalMin: 6000,
        amReminderHour: 8,
        amReminderMinute: 0
    )
}

enum CalendarDay {
    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
