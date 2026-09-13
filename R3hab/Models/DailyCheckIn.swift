import Foundation
import SwiftData

@Model
final class DailyCheckIn {
    @Attribute(.unique) var dayKey: String
    var date: Date
    var restingPainAM: Int?
    var dailyPainPM: Int?
    /// Unused. Kept so existing SwiftData stores do not need a schema migration.
    var lowerBackPainAM: Int?
    /// Unused. Kept so existing SwiftData stores do not need a schema migration.
    var lowerBackPainPM: Int?
    var steps: Int?
    var phaseRaw: String
    var notes: String
    var declineSquatL: Int?
    var declineSquatR: Int?
    var createdAt: Date
    var updatedAt: Date

    var phase: RehabPhase {
        get { RehabPhase.normalized(rawValue: phaseRaw) }
        set { phaseRaw = newValue.rawValue }
    }

    init(
        date: Date,
        calendar: Calendar = .current,
        phase: RehabPhase = .aFlareDeLoad
    ) {
        let start = calendar.startOfDay(for: date)
        self.date = start
        self.dayKey = Self.dayKey(for: start, calendar: calendar)
        self.phaseRaw = phase.rawValue
        self.notes = ""
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
