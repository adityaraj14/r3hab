import XCTest
@testable import R3hab

final class TodayPlannerTests: XCTestCase {
    private let a = UUID()
    private let b = UUID()

    private func input(
        morning: Bool = false,
        evening: Bool = false,
        overdue: [UUID] = [],
        afterPain: [UUID] = [],
        trained: Bool = false,
        isEvening: Bool = false,
        restDay: Bool = false
    ) -> TodayPlannerInput {
        TodayPlannerInput(
            hasMorningPain: morning,
            hasEveningPain: evening,
            overduePending: overdue,
            missingAfterPain: afterPain,
            trainedToday: trained,
            isEvening: isEvening,
            isRestDay: restDay
        )
    }

    func testOverduePendingBeatsEverything() {
        let pick = TodayPlanner.nextAction(input(overdue: [a, b], afterPain: [b]))
        XCTAssertEqual(pick, .resolvePending(sessionID: a, remaining: 1))
    }

    func testFreshDayStartsWithMorning() {
        XCTAssertEqual(TodayPlanner.nextAction(input()), .logMorning)
        XCTAssertEqual(TodayPlanner.nextAction(input(afterPain: [a])), .logMorning)
    }

    func testAfterPainComesRightAfterMorning() {
        XCTAssertEqual(
            TodayPlanner.nextAction(input(morning: true, afterPain: [a, b])),
            .logAfterPain(sessionID: a)
        )
    }

    func testDaytimeDefaultIsTheSession() {
        XCTAssertEqual(TodayPlanner.nextAction(input(morning: true)), .logSession)
    }

    func testEveningWinsOverSessionOnceReminderHourPasses() {
        XCTAssertEqual(
            TodayPlanner.nextAction(input(morning: true, isEvening: true)),
            .logEvening
        )
        XCTAssertEqual(
            TodayPlanner.nextAction(input(morning: true, evening: true, isEvening: true)),
            .logSession
        )
    }

    func testTrainedFallsThroughToEveningThenDone() {
        XCTAssertEqual(TodayPlanner.nextAction(input(morning: true, trained: true)), .logEvening)
        XCTAssertEqual(
            TodayPlanner.nextAction(input(morning: true, evening: true, trained: true)),
            .allDone
        )
    }

    // MARK: Rest day

    func testRestDayNeverPromotesTheLift() {
        XCTAssertEqual(TodayPlanner.nextAction(input(morning: true, restDay: true)), .restDay)
        XCTAssertNotEqual(TodayPlanner.nextAction(input(morning: true, restDay: true)), .logSession)
    }

    func testRestDayStillRunsTheCheckInLoop() {
        XCTAssertEqual(TodayPlanner.nextAction(input(restDay: true)), .logMorning)
        XCTAssertEqual(
            TodayPlanner.nextAction(input(overdue: [a], restDay: true)),
            .resolvePending(sessionID: a, remaining: 0)
        )
        XCTAssertEqual(
            TodayPlanner.nextAction(input(morning: true, afterPain: [b], restDay: true)),
            .logAfterPain(sessionID: b)
        )
        XCTAssertEqual(TodayPlanner.nextAction(input(morning: true, isEvening: true, restDay: true)), .logEvening)
        XCTAssertEqual(TodayPlanner.nextAction(input(morning: true, evening: true, restDay: true)), .allDone)
    }

    func testLogSessionEyebrowSignalsASavedDraft() {
        XCTAssertEqual(TodayPlanner.eyebrow(for: .logSession), "Next up")
        XCTAssertEqual(TodayPlanner.eyebrow(for: .logSession, hasSessionDraft: true), "Draft saved")
    }

    func testDraftDoesNotRewriteOtherNextUpEyebrows() {
        XCTAssertEqual(TodayPlanner.eyebrow(for: .logMorning, hasSessionDraft: true), "Next up")
        XCTAssertEqual(TodayPlanner.eyebrow(for: .logEvening, hasSessionDraft: true), "Next up")
        XCTAssertEqual(TodayPlanner.eyebrow(for: .logAfterPain(sessionID: a), hasSessionDraft: true), "Next up")
        XCTAssertEqual(
            TodayPlanner.eyebrow(for: .resolvePending(sessionID: a, remaining: 0), hasSessionDraft: true),
            "Needs your 24h call"
        )
        XCTAssertEqual(TodayPlanner.eyebrow(for: .restDay, hasSessionDraft: true), "Rest day")
        XCTAssertEqual(TodayPlanner.eyebrow(for: .allDone, hasSessionDraft: true), "Today")
    }

    func testAllDoneLineIsAdisSignOff() {
        XCTAssertEqual(TodayPlanner.allDoneLine, "All done for the day. Let’s pick it back up tomorrow.")
        XCTAssertFalse(TodayPlanner.allDoneLine.contains("Judge it by tomorrow morning"))
        XCTAssertFalse(TodayPlanner.allDoneLine.contains("Morning, load, and evening"))
    }

    func testOptionalLiftOnARestDayFallsThroughLikeAnyTrainedDay() {
        XCTAssertEqual(TodayPlanner.nextAction(input(morning: true, trained: true, restDay: true)), .logEvening)
        XCTAssertEqual(
            TodayPlanner.nextAction(input(morning: true, evening: true, trained: true, restDay: true)),
            .allDone
        )
    }

    func testDueDayPromotesTheLiftAgain() {
        // `isRestDay` is false from the due day onward, so the default returns.
        XCTAssertEqual(TodayPlanner.nextAction(input(morning: true, restDay: false)), .logSession)
    }

    func testIsEveningUsesReminderTime() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let at1829 = cal.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 18, minute: 29))!
        let at1830 = cal.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 18, minute: 30))!
        XCTAssertFalse(TodayPlanner.isEvening(now: at1829, pmReminderHour: 18, pmReminderMinute: 30, calendar: cal))
        XCTAssertTrue(TodayPlanner.isEvening(now: at1830, pmReminderHour: 18, pmReminderMinute: 30, calendar: cal))
    }

    func testRecentMissingAfterPainDropsStaleSessionsAndSortsNewestFirst() {
        let now = Date()
        func snap(_ id: UUID, hoursAgo: Double, after: Int = PainScore.notLogged) -> TrainingSessionSnapshot {
            TrainingSessionSnapshot(
                id: id,
                date: now.addingTimeInterval(-hoursAgo * 3600),
                createdAt: now.addingTimeInterval(-hoursAgo * 3600),
                sessionType: .isometrics,
                response24h: .pending,
                decision: nil,
                resolvedAt: nil,
                snoozedUntil: nil,
                phase: .bIsometrics,
                painDuring: 2,
                painAfter: after
            )
        }
        let stale = UUID()
        let logged = UUID()
        let ids = TodayPlanner.recentMissingAfterPain(
            sessions: [snap(a, hoursAgo: 30), snap(stale, hoursAgo: 72), snap(b, hoursAgo: 2), snap(logged, hoursAgo: 1, after: 1)],
            now: now
        )
        XCTAssertEqual(ids, [b, a])
    }
}
