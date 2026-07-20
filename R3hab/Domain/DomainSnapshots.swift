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

    init(
        id: UUID = UUID(),
        date: Date,
        createdAt: Date,
        sessionType: SessionType,
        response24h: Response24h,
        decision: SessionDecision?,
        resolvedAt: Date?,
        snoozedUntil: Date?,
        phase: RehabPhase
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
