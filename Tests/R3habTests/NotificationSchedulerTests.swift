import XCTest
import UserNotifications
@testable import R3hab

final class NotificationSchedulerTests: XCTestCase {
    func testDailyTriggerComponentsBindLocalCalendarAndTimeZone() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let comps = NotificationScheduler.dailyTriggerComponents(
            hour: 8,
            minute: 0,
            calendar: calendar
        )
        XCTAssertEqual(comps.hour, 8)
        XCTAssertEqual(comps.minute, 0)
        XCTAssertEqual(comps.second, 0)
        XCTAssertEqual(comps.calendar?.identifier, .gregorian)
        XCTAssertEqual(comps.timeZone?.identifier, "America/New_York")
    }

    func testEveningTriggerUsesConfiguredTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let comps = NotificationScheduler.dailyTriggerComponents(
            hour: 18,
            minute: 30,
            calendar: calendar
        )
        XCTAssertEqual(comps.hour, 18)
        XCTAssertEqual(comps.minute, 30)
        XCTAssertEqual(comps.second, 0)
    }

    func testDailyCalendarTriggerHasANextFireDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let comps = NotificationScheduler.dailyTriggerComponents(
            hour: 8,
            minute: 0,
            calendar: calendar
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        XCTAssertTrue(trigger.repeats)
        XCTAssertNotNil(
            trigger.nextTriggerDate(),
            "Repeating AM/PM requests must have a nextTriggerDate or iOS never delivers them."
        )
    }

    func testCanDeliverMatchesAuthorizationThatActuallyFires() {
        XCTAssertTrue(NotificationScheduler.canDeliver(.authorized))
        XCTAssertTrue(NotificationScheduler.canDeliver(.provisional))
        XCTAssertTrue(NotificationScheduler.canDeliver(.ephemeral))
        XCTAssertFalse(NotificationScheduler.canDeliver(.denied))
        XCTAssertFalse(NotificationScheduler.canDeliver(.notDetermined))
    }

    func testDailyReminderIdentifiersStayAMAndPMOnly() {
        XCTAssertEqual(NotificationScheduler.amReminderId, "am-reminder")
        XCTAssertEqual(NotificationScheduler.pmReminderId, "pm-reminder")
        XCTAssertFalse(NotificationScheduler.amReminderId.hasPrefix("stretch-"))
        XCTAssertFalse(NotificationScheduler.pmReminderId.hasPrefix("stretch-"))
    }

    func testLeftoverStretchIdsStayCancelledOnReconcile() {
        XCTAssertEqual(NotificationScheduler.leftoverStretchIds, ["stretch-0", "stretch-1", "stretch-2"])
    }

    func testPainAfterIdentifierRoundTrips() {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        XCTAssertEqual(NotificationScheduler.painAfterId(for: id), "pain-after-\(id.uuidString)")
        XCTAssertEqual(NotificationScheduler.sessionId(fromPainAfterId: "pain-after-\(id.uuidString)"), id)
        XCTAssertNil(NotificationScheduler.sessionId(fromPainAfterId: "pending-\(id.uuidString)"))
        XCTAssertEqual(NotificationScheduler.sessionId(fromPendingId: "pending-\(id.uuidString)"), id)
    }

    func testPainAfterFireDateIsThirtyMinutesWhenStillUpcoming() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let now = created.addingTimeInterval(5 * 60)
        let fire = NotificationScheduler.painAfterFireDate(createdAt: created, now: now)
        XCTAssertEqual(fire, created.addingTimeInterval(30 * 60))
    }

    func testPainAfterFireDateCatchesUpWithinTwelveHours() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let now = created.addingTimeInterval(40 * 60)
        let fire = NotificationScheduler.painAfterFireDate(createdAt: created, now: now)
        XCTAssertEqual(fire, now.addingTimeInterval(60))
    }

    func testPainAfterFireDateStopsAfterCatchUpWindow() {
        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let now = created.addingTimeInterval(13 * 60 * 60)
        XCTAssertNil(NotificationScheduler.painAfterFireDate(createdAt: created, now: now))
    }

    func testHardOverdueIdentifierIsStable() {
        XCTAssertEqual(NotificationScheduler.hardOverdueId, "hard-session-overdue")
    }

    // MARK: Missed-session cue (calendar-day due day)

    private let localCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    /// Local wall-clock moment on 2026-03-02 (a Monday) plus `day` days.
    private func at(day: Int, hour: Int, minute: Int = 0) -> Date {
        let base = localCalendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let dayStart = localCalendar.date(byAdding: .day, value: day, to: base)!
        return localCalendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart)!
    }

    private func fireDate(lastHardDate: Date, now: Date) -> Date? {
        NotificationScheduler.hardOverdueFireDate(
            lastHardDate: lastHardDate,
            amHour: 8,
            amMinute: 0,
            now: now,
            calendar: localCalendar
        )
    }

    func testHardOverdueFiresTheMorningAfterTheDueDayNotAt48Hours() {
        // Trained 7 AM Monday → due Wednesday (whole day) → cue Thursday 8 AM.
        let last = at(day: 0, hour: 7)
        XCTAssertEqual(fireDate(lastHardDate: last, now: at(day: 0, hour: 7, minute: 30)), at(day: 3, hour: 8))
        XCTAssertNotEqual(
            fireDate(lastHardDate: last, now: at(day: 0, hour: 7, minute: 30)),
            last.addingTimeInterval(48 * 3600),
            "A strict 48h timer would have fired Wednesday 7 AM, before the due day was over."
        )
    }

    func testHardOverdueIsStillInTheFutureLateOnTheDueDay() throws {
        // Adi’s case: 7 AM two days ago, no session yet at 5 PM on the due day.
        // The cue must not be “already due” — the user still has the evening.
        let last = at(day: 0, hour: 7)
        let now = at(day: 2, hour: 17)
        let fire = try XCTUnwrap(fireDate(lastHardDate: last, now: now))
        XCTAssertEqual(fire, at(day: 3, hour: 8))
        XCTAssertGreaterThan(fire, now)
    }

    func testHardOverdueUsesTheSessionDayNotTheClockMoment() {
        // Same due day whether the session was logged at 00:10 or 23:50.
        XCTAssertEqual(fireDate(lastHardDate: at(day: 0, hour: 0, minute: 10), now: at(day: 0, hour: 1)), at(day: 3, hour: 8))
        XCTAssertEqual(fireDate(lastHardDate: at(day: 0, hour: 23, minute: 50), now: at(day: 1, hour: 1)), at(day: 3, hour: 8))
    }

    func testHardOverdueCatchesUpWhileStillOneMiss() {
        let last = at(day: 0, hour: 7)
        let now = at(day: 3, hour: 14)
        XCTAssertEqual(fireDate(lastHardDate: last, now: now), now.addingTimeInterval(60))

        let lastOneMissDay = at(day: 4, hour: 22)
        XCTAssertEqual(fireDate(lastHardDate: last, now: lastOneMissDay), lastOneMissDay.addingTimeInterval(60))
    }

    func testHardOverdueStopsOnceTwoDueDaysAreMissed() {
        let last = at(day: 0, hour: 7)
        XCTAssertNil(fireDate(lastHardDate: last, now: at(day: 5, hour: 9)))
    }

    func testMissedSessionCopyIsAdis() {
        XCTAssertEqual(WorkoutStreak.missTwiceTitle, "Don’t miss twice")
        XCTAssertEqual(
            WorkoutStreak.missTwiceBody,
            "One miss is alright, but try not to miss twice. Consistency is what matters the most. Keep going."
        )
    }
}
