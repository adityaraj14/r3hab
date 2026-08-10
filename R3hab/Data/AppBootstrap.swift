import Foundation
import SwiftData

enum AppBootstrap {
    /// Ensure a single AppSettings row exists (first launch seed).
    @MainActor
    static func ensureSettings(context: ModelContext) throws -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try context.fetch(descriptor).first {
            // Personal default: evening check-in moved from 21:00 → 18:30.
            // Only rewrite the old stock default so custom times stay intact.
            if existing.pmReminderHour == 21, existing.pmReminderMinute == 0 {
                existing.pmReminderHour = 18
                existing.pmReminderMinute = 30
            }
            // Dual-track defaults for installs that predate activeTracksCSV.
            if existing.activeTracksCSV.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                existing.activeTracksCSV = "knee,lowerBack"
            }
            if existing.backTrackStageRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                existing.backTrackStageRaw = "iso"
            }
            try? context.save()
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        try context.save()
        return settings
    }
}
