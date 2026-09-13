import Foundation
import SwiftData

/// Fetch-or-insert persistence for one day’s check-in, keyed by dayKey.
/// Callers pass values and a context; no `DailyCheckIn` instance is ever
/// handed back to the UI, so nothing can go stale across a suspend.
enum DailyCheckInStore {
    @MainActor
    static func values(
        forDay date: Date,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> DailyCheckInValues? {
        guard let row = try fetch(dayKey: DailyCheckIn.dayKey(for: date, calendar: calendar), context: context) else {
            return nil
        }
        return DailyCheckInValues(
            restingPainAM: row.restingPainAM,
            dailyPainPM: row.dailyPainPM,
            steps: row.steps,
            phase: row.phase,
            notes: row.notes,
            declineSquatL: row.declineSquatL,
            declineSquatR: row.declineSquatR
        )
    }

    /// Writes `values` to the row for `date`, inserting it if missing, on the
    /// context that is current *now*. Returns nothing on purpose.
    @MainActor
    static func upsert(
        day date: Date,
        values: DailyCheckInValues,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws {
        let day = calendar.startOfDay(for: date)
        let key = DailyCheckIn.dayKey(for: day, calendar: calendar)
        let row: DailyCheckIn
        if let existing = try fetch(dayKey: key, context: context) {
            row = existing
        } else {
            row = DailyCheckIn(date: day, calendar: calendar, phase: values.phase)
            context.insert(row)
        }
        row.restingPainAM = values.restingPainAM
        row.dailyPainPM = values.dailyPainPM
        row.steps = values.steps
        row.phase = values.phase
        row.notes = values.notes
        row.declineSquatL = values.declineSquatL
        row.declineSquatR = values.declineSquatR
        row.updatedAt = Date()
        try context.save()
    }

    @MainActor
    private static func fetch(dayKey: String, context: ModelContext) throws -> DailyCheckIn? {
        let predicate = #Predicate<DailyCheckIn> { $0.dayKey == dayKey }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
