import XCTest
@testable import R3hab

final class PendingQueueTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    func testOverdueOldestFirst() {
        let now = Date(timeIntervalSince1970: 1_700_100_000)
        let today = calendar.startOfDay(for: now)
        let mon = calendar.date(byAdding: .day, value: -3, to: today)!
        let wed = calendar.date(byAdding: .day, value: -1, to: today)!

        let sessions = [
            TrainingSessionSnapshot(
                id: UUID(), date: wed, createdAt: wed,
                sessionType: .isometrics, response24h: .pending, decision: nil,
                resolvedAt: nil, snoozedUntil: nil, phase: .bIsometrics
            ),
            TrainingSessionSnapshot(
                id: UUID(), date: mon, createdAt: mon,
                sessionType: .isometrics, response24h: .pending, decision: nil,
                resolvedAt: nil, snoozedUntil: nil, phase: .bIsometrics
            )
        ]
        let overdue = PendingQueue.overdue(sessions: sessions, now: now, calendar: calendar)
        XCTAssertEqual(overdue.map(\.date), [mon, wed])
    }

    func testActiveSnoozeHidesFromOverdue() {
        let now = Date(timeIntervalSince1970: 1_700_100_000)
        let today = calendar.startOfDay(for: now)
        let mon = calendar.date(byAdding: .day, value: -2, to: today)!
        let until = now.addingTimeInterval(3600)
        let sessions = [
            TrainingSessionSnapshot(
                id: UUID(), date: mon, createdAt: mon,
                sessionType: .isometrics, response24h: .pending, decision: nil,
                resolvedAt: nil, snoozedUntil: until, phase: .bIsometrics
            )
        ]
        XCTAssertTrue(PendingQueue.overdue(sessions: sessions, now: now, calendar: calendar).isEmpty)
    }

    func testNotificationFireInPastNotScheduled() {
        let now = Date(timeIntervalSince1970: 1_700_100_000)
        let past = now.addingTimeInterval(-3600)
        XCTAssertFalse(PendingQueue.shouldScheduleNotification(fireAt: past, now: now))
        XCTAssertTrue(PendingQueue.shouldScheduleNotification(fireAt: now.addingTimeInterval(3600), now: now))
    }
}
