import Foundation
import SwiftUI

/// Shared navigation for deep links / notification taps.
@Observable
final class AppRouter {
    var selectedTab: Int = 0
    var resolveSessionId: UUID?
    var afterPainSessionId: UUID?
    /// Bumps when notifications or data should reschedule.
    var notificationSyncToken: Int = 0
    /// TEMPORARY: TestFlight replay. Remove with Settings “Simulate onboarding”.
    var onboardingReplayToken: Int = 0

    func openResolve(sessionId: UUID) {
        selectedTab = 0
        resolveSessionId = sessionId
    }

    func openAfterPain(sessionId: UUID) {
        selectedTab = 0
        afterPainSessionId = sessionId
    }

    func openToday() {
        selectedTab = 0
    }

    /// Notification tap. The sheets look up the session themselves and show
    /// "Session not found" for a deleted row or a draft.
    func open(_ open: NotificationOpen) {
        switch open.kind {
        case .painAfter:
            if let id = open.sessionId { openAfterPain(sessionId: id) } else { openToday() }
        case .pending:
            if let id = open.sessionId { openResolve(sessionId: id) } else { openToday() }
        case .hardOverdue, .today:
            openToday()
        }
    }

    func requestNotificationSync() {
        notificationSyncToken &+= 1
    }

    /// TEMPORARY: re-present onboarding without wiping logs. Remove before App Store.
    func requestOnboardingReplay() {
        onboardingReplayToken &+= 1
    }
}
