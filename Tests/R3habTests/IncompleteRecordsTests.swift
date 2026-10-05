import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class IncompleteRecordsTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }

    /// Monday Oct 5, 2026 08:00 ET
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 8, minute: 0))!
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!
    }

    private func session(
        daysAgo: Int,
        isDraft: Bool = false,
        response: Response24h = .pending,
        type: SessionType = .hsrStrength
    ) -> TrainingSessionSnapshot {
        let d = day(-daysAgo)
        return TrainingSessionSnapshot(
            id: UUID(),
            date: d,
            createdAt: d.addingTimeInterval(3600 * 18),
            sessionType: type,
            response24h: response,
            decision: nil,
            resolvedAt: response == .pending ? nil : d.addingTimeInterval(3600 * 30),
            snoozedUntil: nil,
            phase: .cHeavySlowResistance,
            painDuring: isDraft ? PainScore.notLogged : 2,
            painAfter: 1,
            isDraft: isDraft,
            whatIDid: "Seated leg extension"
        )
    }

    private func checkIn(daysAgo: Int, am: Bool, pm: Bool) -> IncompleteDayCheckIn {
        IncompleteDayCheckIn(date: day(-daysAgo), hasMorningPain: am, hasEveningPain: pm)
    }

    func testIgnoresToday() {
        let todayDraft = session(daysAgo: 0, isDraft: true)
        let items = IncompleteRecords.items(
            sessions: [todayDraft],
            checkIns: [checkIn(daysAgo: 0, am: false, pm: false)],
            now: now,
            calendar: calendar
        )
        XCTAssertTrue(items.isEmpty)
    }

    func testFindsUnfinishedDraftOnEarlierDay() {
        let draft = session(daysAgo: 1, isDraft: true)
        let items = IncompleteRecords.items(sessions: [draft], checkIns: [], now: now, calendar: calendar)
        XCTAssertEqual(items.count, 3) // draft + missing am + missing pm (footprint from draft)
        XCTAssertEqual(items.first?.kind, .unfinishedDraft(sessionID: draft.id))
    }

    func testFindsMissingEveningPain() {
        let items = IncompleteRecords.items(
            sessions: [],
            checkIns: [checkIn(daysAgo: 1, am: true, pm: false)],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(items.map(\.kind), [.missingEveningPain])
    }

    func testFindsMissingMorningPain() {
        let items = IncompleteRecords.items(
            sessions: [],
            checkIns: [checkIn(daysAgo: 2, am: false, pm: true)],
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(items.map(\.kind), [.missingMorningPain])
    }

    func testFindsDue24hResponse() {
        let s = session(daysAgo: 1, response: .pending)
        let items = IncompleteRecords.items(sessions: [s], checkIns: [checkIn(daysAgo: 1, am: true, pm: true)], now: now, calendar: calendar)
        XCTAssertEqual(items.map(\.kind), [.due24hResponse(sessionID: s.id)])
    }

    func testLookbackStopsAtSevenDays() {
        let old = session(daysAgo: 8, isDraft: true)
        let edge = session(daysAgo: 7, isDraft: true)
        let items = IncompleteRecords.items(sessions: [old, edge], checkIns: [], now: now, calendar: calendar)
        XCTAssertTrue(items.contains { if case .unfinishedDraft(let id) = $0.kind { return id == edge.id }; return false })
        XCTAssertFalse(items.contains { if case .unfinishedDraft(let id) = $0.kind { return id == old.id }; return false })
    }

    func testNewestDayFirst() {
        let a = checkIn(daysAgo: 3, am: true, pm: false)
        let b = checkIn(daysAgo: 1, am: true, pm: false)
        let items = IncompleteRecords.items(sessions: [], checkIns: [a, b], now: now, calendar: calendar)
        XCTAssertEqual(items.map { CalendarDay.dayKey($0.day, calendar: calendar) }, [
            CalendarDay.dayKey(day(-1), calendar: calendar),
            CalendarDay.dayKey(day(-3), calendar: calendar)
        ])
    }

    func testBecomesMainCardOnlyWhenTodayIsCalm() {
        XCTAssertTrue(IncompleteRecords.becomesMainCard(todayAction: .allDone))
        XCTAssertTrue(IncompleteRecords.becomesMainCard(todayAction: .restDay))
        XCTAssertFalse(IncompleteRecords.becomesMainCard(todayAction: .logMorning))
        XCTAssertFalse(IncompleteRecords.becomesMainCard(todayAction: .logEvening))
        let id = UUID()
        XCTAssertFalse(IncompleteRecords.becomesMainCard(todayAction: .resolvePending(sessionID: id, remaining: 0)))
    }

    func testNotificationBodyUsesSTE() {
        let item = IncompleteItem(day: day(-1), kind: .missingEveningPain)
        let body = IncompleteRecords.Copy.notificationBody([item], now: now, calendar: calendar)
        XCTAssertEqual(body, "Yesterday: evening pain.")
        XCTAssertEqual(IncompleteRecords.Copy.cardTitle, "Complete the pending record")
    }

    func testSchedulesOnlyWhenItemsExist() {
        XCTAssertFalse(IncompleteRecords.shouldScheduleNotification(items: []))
        XCTAssertTrue(IncompleteRecords.shouldScheduleNotification(items: [
            IncompleteItem(day: day(-1), kind: .missingMorningPain)
        ]))
    }

    func testNotificationFireUsesMorningReminder() {
        let fire = IncompleteRecords.notificationFireDate(now: now, amHour: 8, amMinute: 0, calendar: calendar)
        // now is exactly 08:00, so next fire is tomorrow 08:00
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        var comps = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        comps.hour = 8
        comps.minute = 0
        XCTAssertEqual(fire, calendar.date(from: comps))
    }
}
