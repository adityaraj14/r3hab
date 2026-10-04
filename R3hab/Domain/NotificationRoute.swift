import Foundation

enum NotificationOpenKind: String, Sendable {
    case pending
    case painAfter
    case hardOverdue
    /// Morning and evening reminders, and any other tap: open Today.
    case today
}

/// Where a notification tap goes. Pure, so it is testable without UIKit.
struct NotificationOpen: Equatable, Sendable {
    var sessionId: UUID?
    var kind: NotificationOpenKind
}

enum NotificationRoute {
    static let pendingPrefix = "pending-"
    static let painAfterPrefix = "pain-after-"
    static let hardOverdueId = "hard-session-overdue"

    static func sessionId(fromPendingId identifier: String) -> UUID? {
        guard identifier.hasPrefix(pendingPrefix) else { return nil }
        return UUID(uuidString: String(identifier.dropFirst(pendingPrefix.count)))
    }

    static func sessionId(fromPainAfterId identifier: String) -> UUID? {
        guard identifier.hasPrefix(painAfterPrefix) else { return nil }
        return UUID(uuidString: String(identifier.dropFirst(painAfterPrefix.count)))
    }

    /// Reads the payload first, then the request identifier.
    /// A session tap without a valid session id opens Today, not an empty sheet.
    static func parse(identifier: String, userInfo: [AnyHashable: Any]) -> NotificationOpen {
        let payloadId = (userInfo["sessionId"] as? String).flatMap { UUID(uuidString: $0) }
        let sessionId = payloadId
            ?? sessionId(fromPainAfterId: identifier)
            ?? sessionId(fromPendingId: identifier)

        let kind: NotificationOpenKind
        if let raw = userInfo["kind"] as? String, let parsed = NotificationOpenKind(rawValue: raw) {
            kind = parsed
        } else if identifier == hardOverdueId {
            kind = .hardOverdue
        } else if identifier.hasPrefix(painAfterPrefix) {
            kind = .painAfter
        } else if identifier.hasPrefix(pendingPrefix) {
            kind = .pending
        } else {
            kind = .today
        }

        switch kind {
        case .pending, .painAfter:
            guard let sessionId else { return NotificationOpen(sessionId: nil, kind: .today) }
            return NotificationOpen(sessionId: sessionId, kind: kind)
        case .hardOverdue, .today:
            return NotificationOpen(sessionId: nil, kind: kind)
        }
    }
}

/// Holds a tap until the app installs its handler.
/// On a cold launch from a notification, the tap can arrive before the first
/// view runs its `.task`. The last tap is kept and delivered then.
/// Use it on the main thread only.
final class NotificationOpenInbox {
    private(set) var waiting: NotificationOpen?

    var handler: ((NotificationOpen) -> Void)? {
        didSet { flush() }
    }

    func deliver(_ open: NotificationOpen) {
        if let handler {
            handler(open)
        } else {
            waiting = open
        }
    }

    private func flush() {
        guard let handler, let open = waiting else { return }
        waiting = nil
        handler(open)
    }
}
