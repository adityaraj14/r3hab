import Foundation
import UserNotifications

/// Local notifications: AM/PM check-ins, stretch reminders, and pending 24h nags (PR-13).
enum NotificationScheduler {
    static let amReminderId = "am-reminder"
    static let pmReminderId = "pm-reminder"

    /// Evenly spaced across 08:00–19:00: 08:00, 13:30, 19:00.
    static let stretchReminderTimes: [(hour: Int, minute: Int)] = [
        (8, 0),
        (13, 30),
        (19, 0)
    ]

    static func stretchReminderId(index: Int) -> String {
        "stretch-\(index)"
    }

    static var stretchReminderIds: [String] {
        stretchReminderTimes.indices.map { stretchReminderId(index: $0) }
    }

    static func pendingId(for sessionId: UUID) -> String {
        "pending-\(sessionId.uuidString)"
    }

    /// Formatted stretch times for Settings/onboarding copy (e.g. "8:00 AM · 1:30 PM · 7:00 PM").
    static var stretchReminderTimesLabel: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "h:mm a"
        return stretchReminderTimes.compactMap { time in
            var comps = DateComponents()
            comps.hour = time.hour
            comps.minute = time.minute
            guard let date = Calendar.current.date(from: comps) else { return nil }
            return formatter.string(from: date)
        }.joined(separator: " · ")
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Full reconcile: daily reminders + stretch + all pending session nags.
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
        let dailyIds = [amReminderId, pmReminderId] + stretchReminderIds

        if !notificationsEnabled {
            await center.removePendingNotificationRequests(withIdentifiers: dailyIds)
            let pending = await center.pendingNotificationRequests()
            let ids = pending.map(\.identifier).filter { $0.hasPrefix("pending-") }
            if !ids.isEmpty {
                await center.removePendingNotificationRequests(withIdentifiers: ids)
            }
            updateBadge(count: 0)
            return
        }

        scheduleDailyReminder(
            id: amReminderId,
            hour: amHour,
            minute: amMinute,
            title: "Morning check-in",
            body: "Log resting pain and stiffness when you’re ready."
        )
        scheduleDailyReminder(
            id: pmReminderId,
            hour: pmHour,
            minute: pmMinute,
            title: "Evening check-in",
            body: "Log daily pain and steps for today."
        )

        for (index, time) in stretchReminderTimes.enumerated() {
            scheduleDailyReminder(
                id: stretchReminderId(index: index),
                hour: time.hour,
                minute: time.minute,
                title: "Time to stretch",
                body: "Take a few minutes to stretch — especially your lower back and legs."
            )
        }

        // Rebuild pending nags: cancel all pending-* then schedule valid ones
        let existing = await center.pendingNotificationRequests()
        let oldPending = existing.map(\.identifier).filter { $0.hasPrefix("pending-") }
        if !oldPending.isEmpty {
            await center.removePendingNotificationRequests(withIdentifiers: oldPending)
        }

        for session in pendingSessions {
            schedulePending(
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
        body: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
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

        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: pendingId(for: sessionId),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
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
