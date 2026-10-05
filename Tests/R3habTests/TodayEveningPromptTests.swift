import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

/// Evening pain becomes the primary card once it is evening, on rest days and
/// training days. Priority: 24-hour response > morning pain > after pain > evening pain.
final class TodayEveningPromptTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()

    private func at(_ hour: Int, _ minute: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: hour, minute: minute))!
    }

    private func evening(_ hour: Int, _ minute: Int, reminder: (Int, Int) = (18, 30)) -> Bool {
        TodayPlanner.isEvening(
            now: at(hour, minute),
            pmReminderHour: reminder.0,
            pmReminderMinute: reminder.1,
            calendar: cal
        )
    }

    private func input(
        morning: Bool = true,
        evening: Bool = false,
        overdue: [UUID] = [],
        missingAfter: [UUID] = [],
        trained: Bool = false,
        isEvening: Bool,
        restDay: Bool = false
    ) -> TodayPlannerInput {
        TodayPlannerInput(
            hasMorningPain: morning,
            hasEveningPain: evening,
            overduePending: overdue,
            missingAfterPain: missingAfter,
            trainedToday: trained,
            isEvening: isEvening,
            isRestDay: restDay
        )
    }

    // MARK: Time window

    func testEveningStartsAtFivePMWithDefaultReminder() {
        XCTAssertFalse(evening(16, 59))
        XCTAssertTrue(evening(17, 0))
        XCTAssertTrue(evening(17, 57)) // Adi's screenshot time
        XCTAssertTrue(evening(23, 59))
    }

    func testEarlierReminderStartsEveningEarlier() {
        XCTAssertFalse(evening(15, 59, reminder: (16, 0)))
        XCTAssertTrue(evening(16, 0, reminder: (16, 0)))
    }

    func testLaterReminderDoesNotDelayEvening() {
        XCTAssertTrue(evening(17, 0, reminder: (21, 0)))
        XCTAssertFalse(evening(16, 30, reminder: (21, 0)))
    }

    func testMorningAndAfternoonAreNotEvening() {
        XCTAssertFalse(evening(0, 0))
        XCTAssertFalse(evening(8, 0))
        XCTAssertFalse(evening(12, 0))
    }

    // MARK: Adi's case: 17:57, rest day, morning pain recorded, evening pain not recorded

    func testRestDayAtFiveFiftySevenPromotesEveningPain() {
        let isEvening = evening(17, 57)
        XCTAssertEqual(TodayPlanner.nextAction(input(isEvening: isEvening, restDay: true)), .logEvening)
    }

    func testRestDayBeforeEveningStaysCalm() {
        XCTAssertEqual(TodayPlanner.nextAction(input(isEvening: evening(16, 0), restDay: true)), .restDay)
    }

    func testTrainingDayEveningPromotesEveningPainOverTheSession() {
        XCTAssertEqual(TodayPlanner.nextAction(input(isEvening: true, restDay: false)), .logEvening)
        XCTAssertEqual(TodayPlanner.nextAction(input(isEvening: false, restDay: false)), .logSession)
    }

    func testTrainedDayEveningPromotesEveningPain() {
        XCTAssertEqual(TodayPlanner.nextAction(input(trained: true, isEvening: true)), .logEvening)
    }

    func testRecordedEveningPainIsNotPromoted() {
        XCTAssertEqual(TodayPlanner.nextAction(input(evening: true, isEvening: true, restDay: true)), .allDone)
        XCTAssertEqual(TodayPlanner.nextAction(input(evening: true, trained: true, isEvening: true)), .allDone)
    }

    // MARK: Priority

    func testOverdueTwentyFourHourResponseWinsOverEveningPain() {
        let id = UUID()
        XCTAssertEqual(
            TodayPlanner.nextAction(input(overdue: [id], isEvening: true, restDay: true)),
            .resolvePending(sessionID: id, remaining: 0)
        )
    }

    func testMorningPainWinsOverEveningPain() {
        XCTAssertEqual(
            TodayPlanner.nextAction(input(morning: false, isEvening: true, restDay: true)),
            .logMorning
        )
    }

    func testFreshAfterPainWinsOverEveningPain() {
        let id = UUID()
        XCTAssertEqual(
            TodayPlanner.nextAction(input(missingAfter: [id], trained: true, isEvening: true)),
            .logAfterPain(sessionID: id)
        )
    }

}
