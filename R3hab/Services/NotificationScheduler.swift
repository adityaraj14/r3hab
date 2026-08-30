import Foundation
import UserNotifications
import os

/// Local notifications: AM/PM check-ins and pending 24h nags.
enum NotificationScheduler {
    static let amReminderId = "am-reminder"
    static let pmReminderId = "pm-reminder"

    private static let log = Logger(subsystem: "com.devrising.r3hab", category: "notifications")

    static func pendingId(for sessionId: UUID) -> String {
        "pending-\(sessionId.uuidString)"
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

    /// Full reconcile: daily AM/PM reminders + pending session nags.
    static func reconcile(
        notificationsEnabled: Bool,
        amHour: Int,
        amMinute: Int,
        pmHour: Int,
        pmMinute: Int,
        pendingSessions: [(id: UUID, date: Date, snoozedUntil: Date?)],
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        let center = UNUserNotificationCenter.current()
        let leftoverStretchIds = (0..<3).map { "stretch-\($0)" }
        let dailyIds = [amReminderId, pmReminderId] + leftoverStretchIds
        let status = await authorizationStatus()
        let shouldSchedule = notificationsEnabled && canDeliver(status)

        if !shouldSchedule {
            await center.removePendingNotificationRequests(withIdentifiers: dailyIds)
            let pending = await center.pendingNotificationRequests()
            let ids = pending.map(\.identifier).filter { $0.hasPrefix("pending-") }
            if !ids.isEmpty {
                await center.removePendingNotificationRequests(withIdentifiers: ids)
            }
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

    static func cancelPending(sessionId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [pendingId(for: sessionId)]
        )
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [pendingId(for: sessionId)]
        )
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

/// Handles notification taps → deep resolve.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
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
        if let raw = info["sessionId"] as? String, let id = UUID(uuidString: raw) {
            await MainActor.run {
                onOpenSession?(id)
            }
            return
        }
        // Fallback: parse pending-{uuid} id
        let nid = response.notification.request.identifier
        if nid.hasPrefix("pending-"),
           let id = UUID(uuidString: String(nid.dropFirst("pending-".count))) {
            await MainActor.run {
                onOpenSession?(id)
            }
        }
    }
}
