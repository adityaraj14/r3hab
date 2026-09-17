import Foundation
import SwiftData

/// Shared destructive data helpers (clear-all, notification-aware deletes).
enum LogStore {
    /// Value-type copy of everything notification reconcile needs.
    /// Built on the main actor *before* any `await` so later work never
    /// touches SwiftData models that may have been invalidated after suspend.
    struct NotificationSnapshot: Sendable {
        var notificationsEnabled: Bool
        var amHour: Int
        var amMinute: Int
        var pmHour: Int
        var pmMinute: Int
        var pendingSessions: [(id: UUID, date: Date, snoozedUntil: Date?)]
        var painAfterSessions: [(id: UUID, createdAt: Date)]
        /// Calendar day of the most recent hard session (drives the miss cue).
        var lastHardDate: Date?
        var overdueCount: Int
    }

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
            NotificationScheduler.cancelSessionNotifications(sessionId: id)
        }
        NotificationScheduler.cancelHardOverdue()
        NotificationScheduler.updateBadge(count: 0)
        return (dailies.count, sessions.count)
    }

    @MainActor
    static func pendingSessionTuples(from sessions: [TrainingSession]) -> [(id: UUID, date: Date, snoozedUntil: Date?)] {
        sessions
            .filter { !$0.isDraft && $0.response24h == .pending }
            .map { (id: $0.id, date: $0.date, snoozedUntil: $0.snoozedUntil) }
    }

    @MainActor
    static func painAfterSessionTuples(from sessions: [TrainingSession]) -> [(id: UUID, createdAt: Date)] {
        sessions
            .filter { !$0.isDraft && !$0.hasLoggedPainAfter }
            .map { (id: $0.id, createdAt: $0.createdAt) }
    }

    @MainActor
    static func notificationSnapshot(
        settings: AppSettings,
        sessions: [TrainingSession],
        now: Date = Date()
    ) -> NotificationSnapshot {
        NotificationSnapshot(
            notificationsEnabled: settings.notificationsEnabled,
            amHour: settings.amReminderHour,
            amMinute: settings.amReminderMinute,
            pmHour: settings.pmReminderHour,
            pmMinute: settings.pmReminderMinute,
            pendingSessions: pendingSessionTuples(from: sessions),
            painAfterSessions: painAfterSessionTuples(from: sessions),
            lastHardDate: lastHardDate(from: sessions),
            overdueCount: PendingQueue.overdue(sessions: sessions.map(\.snapshot), now: now).count
        )
    }

    /// Uses `date` (the day trained), not `createdAt`, so a backfilled session
    /// counts for the day it happened.
    @MainActor
    static func lastHardDate(from sessions: [TrainingSession]) -> Date? {
        sessions
            .filter { !$0.isDraft && SessionSpacing.isHard($0.sessionType) }
            .map(\.date)
            .max()
    }

    static func reconcileNotifications(_ snapshot: NotificationSnapshot) async {
        if snapshot.notificationsEnabled {
            _ = await NotificationScheduler.ensureAuthorizedIfNeeded()
        }
        await NotificationScheduler.reconcile(
            notificationsEnabled: snapshot.notificationsEnabled,
            amHour: snapshot.amHour,
            amMinute: snapshot.amMinute,
            pmHour: snapshot.pmHour,
            pmMinute: snapshot.pmMinute,
            pendingSessions: snapshot.pendingSessions,
            painAfterSessions: snapshot.painAfterSessions,
            lastHardDate: snapshot.lastHardDate
        )
        NotificationScheduler.updateBadge(count: snapshot.overdueCount)
    }
}
