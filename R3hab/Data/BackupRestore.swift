import Foundation
import SwiftData

/// The one restore path. The file picker and the backup list both use it.
@MainActor
enum BackupRestore {
    struct Result: Equatable {
        var checkIns: Int
        var sessions: Int
    }

    static func restore(_ data: Data, mode: ImportMode, context: ModelContext) throws -> Result {
        try ExportImportService.importBackup(data: data, mode: mode, context: context)
        let checkIns = (try? context.fetchCount(FetchDescriptor<DailyCheckIn>())) ?? 0
        let sessions = (try? context.fetch(FetchDescriptor<TrainingSession>())) ?? []
        if let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            let snapshot = LogStore.notificationSnapshot(settings: settings, sessions: sessions)
            Task {
                await LogStore.reconcileNotifications(snapshot)
            }
        }
        return Result(checkIns: checkIns, sessions: sessions.count)
    }
}
