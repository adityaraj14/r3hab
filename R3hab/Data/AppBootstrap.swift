import Foundation
import SwiftData

/// One-time settings migrations. Kept separate so they can be unit-tested
/// without touching SwiftData — calling `ensureSettings` must not write on
/// every foreground or we re-open a SQLite lock across suspend (0xdead10cc).
enum SettingsSeedPolicy {
    static let legacyPMReminderHour = 21
    static let legacyPMReminderMinute = 0
    static let currentPMReminderHour = 18
    static let currentPMReminderMinute = 30

    static func shouldMigrateLegacyPMReminder(hour: Int, minute: Int) -> Bool {
        hour == legacyPMReminderHour && minute == legacyPMReminderMinute
    }

    static let knownTrackIDs: Set<String> = [
        RehabTrackID.knee.rawValue,
        RehabTrackID.ql.rawValue
    ]

    static func shouldNormalizeActiveTracks(_ csv: String) -> Bool {
        !knownTrackIDs.contains(csv)
    }

    static func shouldRemapPrimaryLoad(_ id: String, track: RehabTrackID) -> Bool {
        PrimaryLoadCatalog.needsRemap(id, track: track)
    }

    static func shouldRemapInjury(_ id: String) -> Bool {
        InjuryCatalog.needsRemap(id)
    }
}

enum AppBootstrap {
    /// Ensure a single AppSettings row exists (first launch seed).
    /// Subsequent calls are read-only unless a one-time migration still applies.
    @MainActor
    static func ensureSettings(context: ModelContext) throws -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try context.fetch(descriptor).first {
            var changed = false
            if SettingsSeedPolicy.shouldMigrateLegacyPMReminder(
                hour: existing.pmReminderHour,
                minute: existing.pmReminderMinute
            ) {
                existing.pmReminderHour = SettingsSeedPolicy.currentPMReminderHour
                existing.pmReminderMinute = SettingsSeedPolicy.currentPMReminderMinute
                changed = true
            }
            if SettingsSeedPolicy.shouldNormalizeActiveTracks(existing.activeTracksCSV) {
                existing.activeTracksCSV = RehabTrackID.knee.rawValue
                changed = true
            }
            if SettingsSeedPolicy.shouldRemapPrimaryLoad(
                existing.primaryLoadID,
                track: existing.protocolTrack
            ) {
                existing.primaryLoadID = PrimaryLoadCatalog.normalizedID(
                    existing.primaryLoadID,
                    track: existing.protocolTrack
                )
                changed = true
            }
            if SettingsSeedPolicy.shouldRemapInjury(existing.selectedInjuryID) {
                existing.selectedInjuryID = InjuryCatalog.normalizedID(existing.selectedInjuryID)
                changed = true
            }
            if changed {
                try context.save()
            }
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        try context.save()
        return settings
    }
}
