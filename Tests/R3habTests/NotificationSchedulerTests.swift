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
}
