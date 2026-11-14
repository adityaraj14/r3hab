import Foundation
import UserNotifications

/// Local reminders are no longer part of the app. Launch cancels anything
/// already waiting so an older build stops firing.
enum NotificationScheduler {
    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        center.setBadgeCount(0) { _ in }
    }
}
