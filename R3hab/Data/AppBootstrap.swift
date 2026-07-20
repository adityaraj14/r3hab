import Foundation
import SwiftData

enum AppBootstrap {
    /// Ensure a single AppSettings row exists (first launch seed).
    @MainActor
    static func ensureSettings(context: ModelContext) throws -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        try context.save()
        return settings
    }
}
