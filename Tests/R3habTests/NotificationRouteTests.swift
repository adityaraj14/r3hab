import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

/// Notification taps: where each kind goes, stale or missing ids, and a tap
/// that arrives before the app installs its handler (cold launch).
final class NotificationRouteTests: XCTestCase {
    private let id = UUID()

    func testPainAfterPayloadOpensThePainAfterSheet() {
        let open = NotificationRoute.parse(
            identifier: "pain-after-\(id.uuidString)",
            userInfo: ["sessionId": id.uuidString, "kind": "painAfter"]
        )
        XCTAssertEqual(open, NotificationOpen(sessionId: id, kind: .painAfter))
    }

    func test24hPayloadOpensTheResolveSheet() {
        let open = NotificationRoute.parse(
            identifier: "pending-\(id.uuidString)",
            userInfo: ["sessionId": id.uuidString, "kind": "pending"]
        )
        XCTAssertEqual(open, NotificationOpen(sessionId: id, kind: .pending))
    }

    func testIdentifierIsTheFallbackWhenThePayloadIsEmpty() {
        XCTAssertEqual(
            NotificationRoute.parse(identifier: "pain-after-\(id.uuidString)", userInfo: [:]),
            NotificationOpen(sessionId: id, kind: .painAfter)
        )
        XCTAssertEqual(
            NotificationRoute.parse(identifier: "pending-\(id.uuidString)", userInfo: [:]),
            NotificationOpen(sessionId: id, kind: .pending)
        )
    }

    func testOverdueAndDailyRemindersOpenToday() {
        XCTAssertEqual(
            NotificationRoute.parse(identifier: "hard-session-overdue", userInfo: ["kind": "hardOverdue"]),
            NotificationOpen(sessionId: nil, kind: .hardOverdue)
        )
        XCTAssertEqual(
            NotificationRoute.parse(identifier: "am-reminder", userInfo: [:]),
            NotificationOpen(sessionId: nil, kind: .today)
        )
        XCTAssertEqual(
            NotificationRoute.parse(identifier: "pm-reminder", userInfo: [:]),
            NotificationOpen(sessionId: nil, kind: .today)
        )
    }

    func testSessionTapWithoutAValidIdOpensToday() {
        XCTAssertEqual(
            NotificationRoute.parse(identifier: "pending-not-a-uuid", userInfo: ["kind": "pending", "sessionId": "x"]),
            NotificationOpen(sessionId: nil, kind: .today)
        )
        XCTAssertEqual(
            NotificationRoute.parse(identifier: "other", userInfo: ["kind": "painAfter", "sessionId": 42]),
            NotificationOpen(sessionId: nil, kind: .today)
        )
    }

    func testUnknownKindFallsBackToTheIdentifier() {
        XCTAssertEqual(
            NotificationRoute.parse(identifier: "pending-\(id.uuidString)", userInfo: ["kind": "future-kind"]),
            NotificationOpen(sessionId: id, kind: .pending)
        )
    }

    func testIdentifiersRoundTrip() {
        XCTAssertEqual(NotificationRoute.sessionId(fromPainAfterId: "pain-after-\(id.uuidString)"), id)
        XCTAssertNil(NotificationRoute.sessionId(fromPainAfterId: "pending-\(id.uuidString)"))
        XCTAssertEqual(NotificationRoute.sessionId(fromPendingId: "pending-\(id.uuidString)"), id)
        XCTAssertNil(NotificationRoute.sessionId(fromPendingId: "pain-after-\(id.uuidString)"))
    }

    // MARK: Inbox (cold launch)

    func testTapBeforeTheHandlerIsDeliveredOnceTheHandlerIsSet() {
        let inbox = NotificationOpenInbox()
        let tap = NotificationOpen(sessionId: id, kind: .painAfter)
        inbox.deliver(tap)
        XCTAssertEqual(inbox.waiting, tap)

        var received: [NotificationOpen] = []
        inbox.handler = { received.append($0) }
        XCTAssertEqual(received, [tap])
        XCTAssertNil(inbox.waiting)

        // Setting the handler again does not deliver the same tap twice.
        inbox.handler = { received.append($0) }
        XCTAssertEqual(received, [tap])
    }

    func testTapAfterTheHandlerGoesStraightThrough() {
        let inbox = NotificationOpenInbox()
        var received: [NotificationOpen] = []
        inbox.handler = { received.append($0) }
        let tap = NotificationOpen(sessionId: nil, kind: .today)
        inbox.deliver(tap)
        XCTAssertEqual(received, [tap])
        XCTAssertNil(inbox.waiting)
    }
}
