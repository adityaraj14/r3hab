import Foundation
import UserNotifications
import os

/// Local notifications: AM/PM check-ins, pending 24h nags, and post-session pain.
enum NotificationScheduler {
    static let amReminderId = "am-reminder"
    static let pmReminderId = "pm-reminder"
    static let leftoverStretchIds = (0..<3).map { "stretch-\($0)" }
    static let hardOverdueId = "hard-session-overdue"

    /// Remind after the session has settled — not mid-cooldown, not next morning
    /// (that's the 24h resolve). 30 minutes is enough to shower and still remember.
    static let painAfterDelay: TimeInterval = 30 * 60
    /// If reconcile runs after the 30-minute mark, still nudge once within 12 hours.
    static let painAfterCatchUpWindow: TimeInterval = 12 * 60 * 60
    static let painAfterCatchUpDelay: TimeInterval = 60

    private static let log = Logger(subsystem: "com.devrising.r3hab", category: "notifications")

    static func pendingId(for sessionId: UUID) -> String {
        "pending-\(sessionId.uuidString)"
    }

    static func painAfterId(for sessionId: UUID) -> String {
        "pain-after-\(sessionId.uuidString)"
    }

    static func sessionId(fromPendingId identifier: String) -> UUID? {
        guard identifier.hasPrefix("pending-") else { return nil }
        return UUID(uuidString: String(identifier.dropFirst("pending-".count)))
    }

    static func sessionId(fromPainAfterId identifier: String) -> UUID? {
        guard identifier.hasPrefix("pain-after-") else { return nil }
        return UUID(uuidString: String(identifier.dropFirst("pain-after-".count)))
    }

    static func painAfterFireDate(createdAt: Date, now: Date) -> Date? {
        let intended = createdAt.addingTimeInterval(painAfterDelay)
        if intended > now { return intended }
        if now.timeIntervalSince(createdAt) <= painAfterCatchUpWindow {
            return now.addingTimeInterval(painAfterCatchUpDelay)
        }
        return nil
    }

    /// Whether iOS will actually deliver scheduled local notifications.
    static func canDeliver(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// Calendar + time zone must be on the components or `nextTriggerDate()` can be nil
    /// and the repeating AM/PM request never fires (even after a successful `add`).
    static func dailyTriggerComponents(
        hour: Int,
        minute: Int,
        calendar: Calendar = .current
    ) -> DateComponents {
        var comps = DateComponents()
        comps.calendar = calendar
        comps.timeZone = calendar.timeZone
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return comps
    }

    static func pendingTriggerComponents(
        fire: Date,
        calendar: Calendar = .current
    ) -> DateComponents {
        var comps = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fire
        )
        comps.calendar = calendar
        comps.timeZone = calendar.timeZone
        comps.second = 0
        return comps
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            log.error("requestAuthorization failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Request only when undetermined; do not prompt again if already denied.
    static func ensureAuthorizedIfNeeded() async -> Bool {
        let status = await authorizationStatus()
        if canDeliver(status) { return true }
        if status == .denied { return false }
        return await requestAuthorization()
    }

    /// Full reconcile: daily AM/PM reminders + pending session nags + after-pain.
    static func reconcile(
        notificationsEnabled: Bool,
        amHour: Int,
        amMinute: Int,
        pmHour: Int,
        pmMinute: Int,
        pendingSessions: [(id: UUID, date: Date, snoozedUntil: Date?)],
        painAfterSessions: [(id: UUID, createdAt: Date)] = [],
        lastHardCreatedAt: Date? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        let center = UNUserNotificationCenter.current()
        let dailyIds = [amReminderId, pmReminderId] + leftoverStretchIds
        let status = await authorizationStatus()
        let shouldSchedule = notificationsEnabled && canDeliver(status)

        if !shouldSchedule {
            await center.removePendingNotificationRequests(withIdentifiers: dailyIds)
            let pending = await center.pendingNotificationRequests()
            let ids = pending.map(\.identifier).filter {
                $0.hasPrefix("pending-") || $0.hasPrefix("pain-after-") || $0 == hardOverdueId
            }
            if !ids.isEmpty {
                await center.removePendingNotificationRequests(withIdentifiers: ids)
            }
            cancelHardOverdue()
            updateBadge(count: 0)
            return
        }

        // Replace leftover stretch ids and stale AM/PM triggers, then add fresh dailies.
        await center.removePendingNotificationRequests(withIdentifiers: dailyIds)

        await scheduleDailyReminder(
            id: amReminderId,
            hour: amHour,
            minute: amMinute,
            title: "Morning check-in",
            body: "Log resting knee pain when you’re ready.",
            calendar: calendar
        )
        await scheduleDailyReminder(
            id: pmReminderId,
            hour: pmHour,
            minute: pmMinute,
            title: "Evening check-in",
            body: "Log daily pain and steps for today.",
            calendar: calendar
        )

        // Rebuild pending nags: cancel all pending-* then schedule valid ones
        let existing = await center.pendingNotificationRequests()
        let oldPending = existing.map(\.identifier).filter { $0.hasPrefix("pending-") }
        if !oldPending.isEmpty {
            await center.removePendingNotificationRequests(withIdentifiers: oldPending)
        }

        for session in pendingSessions {
            await schedulePendingAsync(
                sessionId: session.id,
                sessionDate: session.date,
                snoozedUntil: session.snoozedUntil,
                amHour: amHour,
                amMinute: amMinute,
                now: now,
                calendar: calendar
            )
        }

        let afterRefresh = await center.pendingNotificationRequests()
        let oldAfter = afterRefresh.map(\.identifier).filter { $0.hasPrefix("pain-after-") }
        if !oldAfter.isEmpty {
            await center.removePendingNotificationRequests(withIdentifiers: oldAfter)
        }
        for session in painAfterSessions {
            await schedulePainAfterAsync(
                sessionId: session.id,
                createdAt: session.createdAt,
                now: now,
                calendar: calendar
            )
        }

        await center.removePendingNotificationRequests(withIdentifiers: [hardOverdueId])
        if let lastHardCreatedAt {
            await scheduleHardOverdueAsync(lastHardAt: lastHardCreatedAt, now: now, calendar: calendar)
        }
    }

    static func scheduleDailyReminder(
        id: String,
        hour: Int,
        minute: Int,
        title: String,
        body: String,
        calendar: Calendar = .current
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = dailyTriggerComponents(hour: hour, minute: minute, calendar: calendar)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        await add(request)
    }

    /// Fire next morning after session.date at AM time, or at snoozedUntil if set.
    /// Only schedules if fire datetime is still in the future.
    static func schedulePending(
        sessionId: UUID,
        sessionDate: Date,
        snoozedUntil: Date?,
        amHour: Int,
        amMinute: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        Task {
            await schedulePendingAsync(
                sessionId: sessionId,
                sessionDate: sessionDate,
                snoozedUntil: snoozedUntil,
                amHour: amHour,
                amMinute: amMinute,
                now: now,
                calendar: calendar
            )
        }
    }

    static func schedulePendingAsync(
        sessionId: UUID,
        sessionDate: Date,
        snoozedUntil: Date?,
        amHour: Int,
        amMinute: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        let fire: Date
        if let snoozedUntil {
            fire = snoozedUntil
        } else {
            fire = PendingQueue.notificationFireDate(
                sessionDate: sessionDate,
                amHour: amHour,
                amMinute: amMinute,
                calendar: calendar
            )
        }
        guard PendingQueue.shouldScheduleNotification(fireAt: fire, now: now) else { return }

        let content = UNMutableNotificationContent()
        content.title = "24h response due"
        content.body = "How did yesterday’s session feel? Tap to resolve."
        content.sound = .default
        content.userInfo = ["sessionId": sessionId.uuidString, "kind": "pending"]
        content.categoryIdentifier = "PENDING_24H"

        let comps = pendingTriggerComponents(fire: fire, calendar: calendar)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: pendingId(for: sessionId),
            content: content,
            trigger: trigger
        )
        await add(request)
    }

    static func schedulePainAfter(
        sessionId: UUID,
        createdAt: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        Task {
            await schedulePainAfterAsync(
                sessionId: sessionId,
                createdAt: createdAt,
                now: now,
                calendar: calendar
            )
        }
    }

    static func schedulePainAfterAsync(
        sessionId: UUID,
        createdAt: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        guard let fire = painAfterFireDate(createdAt: createdAt, now: now) else { return }
        guard PendingQueue.shouldScheduleNotification(fireAt: fire, now: now) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Log post-session pain"
        content.body = "How did the tendon feel after today’s session? Tap to log pain after."
        content.sound = .default
        content.userInfo = ["sessionId": sessionId.uuidString, "kind": "painAfter"]
        content.categoryIdentifier = "PAIN_AFTER"

        let comps = pendingTriggerComponents(fire: fire, calendar: calendar)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: painAfterId(for: sessionId),
            content: content,
            trigger: trigger
        )
        await add(request)
    }

    static func cancelPending(sessionId: UUID) {
        let ids = [pendingId(for: sessionId)]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    static func cancelPainAfter(sessionId: UUID) {
        let ids = [painAfterId(for: sessionId)]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    static func hardOverdueFireDate(lastHardAt: Date, now: Date) -> Date? {
        let intended = lastHardAt.addingTimeInterval(SessionSpacing.hardGap)
        if intended > now { return intended }
        if now.timeIntervalSince(lastHardAt) <= SessionSpacing.hardGap * 2 {
            return now.addingTimeInterval(painAfterCatchUpDelay)
        }
        return nil
    }

    static func scheduleHardOverdueAsync(
        lastHardAt: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        guard let fire = hardOverdueFireDate(lastHardAt: lastHardAt, now: now) else { return }
        guard PendingQueue.shouldScheduleNotification(fireAt: fire, now: now) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Keep the chain"
        content.body = "One miss is alright. Don’t miss twice — a hard session still counts. Inspired by Atomic Habits."
        content.sound = .default
        content.userInfo = ["kind": NotificationOpenKind.hardOverdue.rawValue]
        content.categoryIdentifier = "HARD_OVERDUE"

        let comps = pendingTriggerComponents(fire: fire, calendar: calendar)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: hardOverdueId,
            content: content,
            trigger: trigger
        )
        await add(request)
    }

    static func cancelHardOverdue() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [hardOverdueId]
        )
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [hardOverdueId]
        )
    }

    static func cancelSessionNotifications(sessionId: UUID) {
        let ids = [pendingId(for: sessionId), painAfterId(for: sessionId)]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    static func cancelAllPendingAndReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        Task { @MainActor in
            try? await UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }

    static func updateBadge(count: Int) {
        Task { @MainActor in
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }

    private static func add(_ request: UNNotificationRequest) async {
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            log.error(
                "Failed to add \(request.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

enum NotificationOpenKind: String, Sendable {
    case pending
    case painAfter
    case hardOverdue
}

/// Handles notification taps → deep resolve or after-pain sheet.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    var onOpenNotification: ((UUID?, NotificationOpenKind) -> Void)?
    /// Legacy alias used by older call sites; treated as a 24h resolve.
    var onOpenSession: ((UUID) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let nid = response.notification.request.identifier
        let sessionId = (info["sessionId"] as? String).flatMap(UUID.init(uuidString:))
        let kind: NotificationOpenKind
        if let rawKind = info["kind"] as? String, let parsed = NotificationOpenKind(rawValue: rawKind) {
            kind = parsed
        } else if nid == NotificationScheduler.hardOverdueId {
            kind = .hardOverdue
        } else if nid.hasPrefix("pain-after-") {
            kind = .painAfter
        } else {
            kind = .pending
        }

        let resolvedId = sessionId
            ?? NotificationScheduler.sessionId(fromPainAfterId: nid)
            ?? NotificationScheduler.sessionId(fromPendingId: nid)

        await MainActor.run {
            onOpenNotification?(resolvedId, kind)
            if kind == .pending, let resolvedId {
                onOpenSession?(resolvedId)
            }
        }
    }
}
