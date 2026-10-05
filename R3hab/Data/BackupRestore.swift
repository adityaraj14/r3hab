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
        let checkInRows = (try? context.fetch(FetchDescriptor<DailyCheckIn>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<TrainingSession>())) ?? []
        if let settings = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            let snapshot = LogStore.notificationSnapshot(
                settings: settings,
                sessions: sessions,
                checkIns: checkInRows
            )
            Task {
                await LogStore.reconcileNotifications(snapshot)
            }
        }
        return Result(checkIns: checkInRows.count, sessions: sessions.count)
    }
}
