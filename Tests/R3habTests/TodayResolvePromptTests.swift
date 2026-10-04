import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

/// The quiet "Record the 24-hour response" link on Today.
final class TodayResolvePromptTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 11, minute: 30))!
    }

    private func session(daysAgo: Int, response: Response24h, snoozedUntil: Date? = nil) -> TrainingSessionSnapshot {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        return TrainingSessionSnapshot(
            date: day,
            createdAt: day.addingTimeInterval(9 * 3600),
            sessionType: .hsrStrength,
            response24h: response,
            decision: nil,
            resolvedAt: nil,
            snoozedUntil: snoozedUntil,
            phase: .cHeavySlowResistance,
            painDuring: 2
        )
    }

    /// Adi's report: he saves the due 24-hour response, and Today still says
    /// "Record the 24-hour response". The link was for the session he
    /// recorded today, which is not due until tomorrow.
    func testNoLinkForASessionRecordedToday() {
        let earlier = session(daysAgo: 2, response: .better)
        let today = session(daysAgo: 0, response: .pending)
        let id = TodayResolvePrompt.sessionID(
            latestPendingID: today.id,
            sessions: [earlier, today],
            action: .logEvening,
            now: now,
            calendar: calendar
        )
        XCTAssertNil(id, "A session from today has no 24-hour response yet")
    }

    func testNoLinkLateTonightEither() {
        let today = session(daysAgo: 0, response: .pending)
        let lateTonight = calendar.date(byAdding: .hour, value: 12, to: now)!
        XCTAssertNil(TodayResolvePrompt.sessionID(
            latestPendingID: today.id,
            sessions: [today],
            action: .allDone,
            now: lateTonight,
            calendar: calendar
        ))
    }

    /// "Wait until morning" keeps the session off the gold card until the
    /// reminder. The quiet link still lets Adi record it before then.
    func testLinkForASnoozedSessionFromYesterday() {
        let snoozed = session(daysAgo: 1, response: .pending, snoozedUntil: now.addingTimeInterval(3600))
        XCTAssertEqual(TodayResolvePrompt.sessionID(
            latestPendingID: snoozed.id,
            sessions: [snoozed],
            action: .logSession,
            now: now,
            calendar: calendar
        ), snoozed.id)
    }

    func testNoLinkWhileTheGoldCardAsks() {
        let due = session(daysAgo: 1, response: .pending)
        XCTAssertNil(TodayResolvePrompt.sessionID(
            latestPendingID: due.id,
            sessions: [due],
            action: .resolvePending(sessionID: due.id, remaining: 0),
            now: now,
            calendar: calendar
        ))
    }

    func testNoLinkAfterTheSave() {
        let saved = session(daysAgo: 1, response: .same)
        XCTAssertNil(TodayResolvePrompt.sessionID(
            latestPendingID: saved.id,
            sessions: [saved],
            action: .logSession,
            now: now,
            calendar: calendar
        ))
    }
}
