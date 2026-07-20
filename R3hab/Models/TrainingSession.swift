import Foundation
import SwiftData

@Model
final class TrainingSession {
    @Attribute(.unique) var id: UUID
    var date: Date
    var phaseRaw: String
    var typeRaw: String
    var whatIDid: String
    var painDuring: Int
    var painAfter: Int
    var response24hRaw: String
    var decisionRaw: String?
    var notes: String
    var snoozedUntil: Date?
    var snoozeUsed: Bool
    var resolvedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var phase: RehabPhase {
        get { RehabPhase(rawValue: phaseRaw) ?? .aFlareDeLoad }
        set { phaseRaw = newValue.rawValue }
    }

    var sessionType: SessionType {
        get { SessionType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var response24h: Response24h {
        get { Response24h(rawValue: response24hRaw) ?? .pending }
        set { response24hRaw = newValue.rawValue }
    }

    var decision: SessionDecision? {
        get {
            guard let decisionRaw else { return nil }
            return SessionDecision(rawValue: decisionRaw)
        }
        set { decisionRaw = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        phase: RehabPhase,
        sessionType: SessionType,
        whatIDid: String,
        painDuring: Int,
        painAfter: Int,
        calendar: Calendar = .current
    ) {
        self.id = id
        self.date = calendar.startOfDay(for: date)
        self.phaseRaw = phase.rawValue
        self.typeRaw = sessionType.rawValue
        self.whatIDid = whatIDid
        self.painDuring = painDuring
        self.painAfter = painAfter
        self.response24hRaw = Response24h.pending.rawValue
        self.decisionRaw = nil
        self.notes = ""
        self.snoozedUntil = nil
        self.snoozeUsed = false
        self.resolvedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
