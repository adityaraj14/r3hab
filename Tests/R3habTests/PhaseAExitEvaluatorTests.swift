import XCTest
@testable import R3hab

final class PhaseAExitEvaluatorTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private var settings: PhaseSettingsSnapshot {
        var s = PhaseSettingsSnapshot.default
        s.phaseAPainThreshold = 2
        s.phaseAStableDaysRequired = 3
        s.stepNearNormalMin = 6000
        return s
    }

    private func day(_ offset: Int, from today: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: today))!
    }

    private func snap(dayOffset: Int, from today: Date, am: Int?, steps: Int?) -> DailyCheckInSnapshot {
        DailyCheckInSnapshot(date: day(dayOffset, from: today), restingPainAM: am, steps: steps)
    }

    func testF1_empty() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let status = PhaseAExitEvaluator.evaluate(checkIns: [], settings: settings, today: today, calendar: calendar)
        XCTAssertEqual(status.stableDaysCount, 0)
        XCTAssertFalse(status.isReadyToAdvance)
    }

    func testF3_classicReady() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let checkIns = [
            snap(dayOffset: -2, from: today, am: 2, steps: 5000),
            snap(dayOffset: -1, from: today, am: 2, steps: 5000),
            snap(dayOffset: 0, from: today, am: 2, steps: 7000)
        ]
        let status = PhaseAExitEvaluator.evaluate(checkIns: checkIns, settings: settings, today: today, calendar: calendar)
        XCTAssertEqual(status.stableDaysCount, 3)
        XCTAssertEqual(status.nearNormalStepDaysInStreak, 1)
        XCTAssertTrue(status.isReadyToAdvance)
    }

    func testF5_gapBreaksStreak() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let checkIns = [
            snap(dayOffset: -2, from: today, am: 2, steps: 7000),
            // missing -1
            snap(dayOffset: 0, from: today, am: 2, steps: 7000)
        ]
        let status = PhaseAExitEvaluator.evaluate(checkIns: checkIns, settings: settings, today: today, calendar: calendar)
        XCTAssertEqual(status.stableDaysCount, 1)
        XCTAssertFalse(status.isReadyToAdvance)
    }

    func testF6_nilAMBreaks() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let checkIns = [
            snap(dayOffset: -2, from: today, am: 2, steps: 7000),
            snap(dayOffset: -1, from: today, am: nil, steps: 7000),
            snap(dayOffset: 0, from: today, am: 2, steps: 7000)
        ]
        let status = PhaseAExitEvaluator.evaluate(checkIns: checkIns, settings: settings, today: today, calendar: calendar)
        XCTAssertEqual(status.stableDaysCount, 1)
        XCTAssertFalse(status.isReadyToAdvance)
    }

    func testF7_pain3Breaks() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let checkIns = [
            snap(dayOffset: -2, from: today, am: 2, steps: 7000),
            snap(dayOffset: -1, from: today, am: 3, steps: 7000),
            snap(dayOffset: 0, from: today, am: 2, steps: 7000)
        ]
        let status = PhaseAExitEvaluator.evaluate(checkIns: checkIns, settings: settings, today: today, calendar: calendar)
        XCTAssertEqual(status.stableDaysCount, 1)
        XCTAssertFalse(status.isReadyToAdvance)
    }

    func testF8_nearNormalOnOlderDayInStreak() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let checkIns = [
            snap(dayOffset: -2, from: today, am: 1, steps: 8000),
            snap(dayOffset: -1, from: today, am: 2, steps: 4000),
            snap(dayOffset: 0, from: today, am: 2, steps: 4000)
        ]
        let status = PhaseAExitEvaluator.evaluate(checkIns: checkIns, settings: settings, today: today, calendar: calendar)
        XCTAssertEqual(status.stableDaysCount, 3)
        XCTAssertEqual(status.nearNormalStepDaysInStreak, 1)
        XCTAssertTrue(status.isReadyToAdvance)
    }

    func testF9_anchorYesterdayWhenTodayMissing() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        // only through yesterday
        let checkIns = [
            snap(dayOffset: -3, from: today, am: 2, steps: 7000),
            snap(dayOffset: -2, from: today, am: 2, steps: 7000),
            snap(dayOffset: -1, from: today, am: 2, steps: 7000)
        ]
        let status = PhaseAExitEvaluator.evaluate(checkIns: checkIns, settings: settings, today: today, calendar: calendar)
        XCTAssertEqual(status.stableDaysCount, 3)
        XCTAssertTrue(status.isReadyToAdvance)
    }
}
