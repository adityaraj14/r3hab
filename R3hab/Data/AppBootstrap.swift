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

    /// Retired knee primaries and the removed QL loads (hip thrust / side bend /
    /// walking) rewrite to seated extension.
    static func shouldRemapPrimaryLoad(_ id: String) -> Bool {
        PrimaryLoadCatalog.needsRemap(id)
    }

    /// Collapsed knee aliases and the removed `ql-strain` rewrite to
    /// patellar tendinopathy.
    static func shouldRemapInjury(_ id: String) -> Bool {
        InjuryCatalog.needsRemap(id)
    }

    /// Removed phases D / E rewrite to C. Check-in and session rows remap
    /// lazily through `RehabPhase.normalized`; only settings are rewritten here.
    static func shouldRemapPhase(_ raw: String) -> Bool {
        RehabPhase.needsRemap(raw)
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
            if SettingsSeedPolicy.shouldRemapPrimaryLoad(existing.primaryLoadID) {
                existing.primaryLoadID = PrimaryLoadCatalog.normalizedID(existing.primaryLoadID)
                changed = true
            }
            if SettingsSeedPolicy.shouldRemapInjury(existing.selectedInjuryID) {
                existing.selectedInjuryID = InjuryCatalog.normalizedID(existing.selectedInjuryID)
                changed = true
            }
            if SettingsSeedPolicy.shouldRemapPhase(existing.currentPhaseRaw) {
                // Direct raw write: the `currentPhase` setter would also bump phaseChangedAt.
                existing.currentPhaseRaw = RehabPhase.normalizedRawValue(existing.currentPhaseRaw)
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
