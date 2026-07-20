import Foundation
import SwiftData

/// Shared destructive data helpers (clear-all, notification-aware deletes).
enum LogStore {
    /// Deletes every daily check-in and training session. Keeps AppSettings.
    @MainActor
    static func clearAllLogs(context: ModelContext) throws -> (daily: Int, sessions: Int) {
        let dailies = try context.fetch(FetchDescriptor<DailyCheckIn>())
        let sessions = try context.fetch(FetchDescriptor<TrainingSession>())
        let sessionIds = sessions.map(\.id)
        for d in dailies { context.delete(d) }
        for s in sessions { context.delete(s) }
        try context.save()
        for id in sessionIds {
            NotificationScheduler.cancelPending(sessionId: id)
        }
        NotificationScheduler.updateBadge(count: 0)
        return (dailies.count, sessions.count)
    }

    @MainActor
    static func pendingSessionTuples(from sessions: [TrainingSession]) -> [(id: UUID, date: Date, snoozedUntil: Date?)] {
        sessions
            .filter { $0.response24h == .pending }
            .map { (id: $0.id, date: $0.date, snoozedUntil: $0.snoozedUntil) }
    }

    @MainActor
    static func reconcileNotifications(
        settings: AppSettings,
        sessions: [TrainingSession]
    ) async {
        await NotificationScheduler.reconcile(
            notificationsEnabled: settings.notificationsEnabled,
            amHour: settings.amReminderHour,
            amMinute: settings.amReminderMinute,
            pmHour: settings.pmReminderHour,
            pmMinute: settings.pmReminderMinute,
            pendingSessions: pendingSessionTuples(from: sessions)
        )
        let overdue = PendingQueue.overdue(sessions: sessions.map(\.snapshot), now: Date()).count
        NotificationScheduler.updateBadge(count: overdue)
    }
}
