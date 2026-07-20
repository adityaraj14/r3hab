import Foundation
import SwiftUI

/// Shared navigation for deep links / notification taps.
@Observable
final class AppRouter {
    var selectedTab: Int = 0
    var resolveSessionId: UUID?
    /// Bumps when notifications or data should reschedule.
    var notificationSyncToken: Int = 0

    func openResolve(sessionId: UUID) {
        selectedTab = 0
        resolveSessionId = sessionId
    }

    func requestNotificationSync() {
        notificationSyncToken &+= 1
    }
}
