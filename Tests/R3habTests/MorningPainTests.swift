import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

/// The morning pain ruler: prefill and the comparison text.
final class MorningPainTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func day(_ offset: Int) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 7))!
        return calendar.date(byAdding: .day, value: offset, to: base)!
    }

    func testPrefillIsYesterdaysMorningValue() {
        let checkIns = [
            DailyCheckInSnapshot(date: day(-1), restingPainAM: 3, steps: nil),
            DailyCheckInSnapshot(date: day(-2), restingPainAM: 5, steps: nil)
        ]
        let yesterday = MorningPain.yesterday(before: day(0), checkIns: checkIns, calendar: calendar)
        XCTAssertEqual(yesterday, 3)
        XCTAssertEqual(MorningPain.prefill(yesterday: yesterday), 3)
    }

    func testPrefillIsZeroWithoutAMorningValueYesterday() {
        // Yesterday has a row with no morning value. Two days ago does not count.
        let checkIns = [
            DailyCheckInSnapshot(date: day(-1), restingPainAM: nil, steps: 4000),
            DailyCheckInSnapshot(date: day(-2), restingPainAM: 5, steps: nil)
        ]
        let yesterday = MorningPain.yesterday(before: day(0), checkIns: checkIns, calendar: calendar)
        XCTAssertNil(yesterday)
        XCTAssertEqual(MorningPain.prefill(yesterday: yesterday), 0)
        XCTAssertNil(MorningPain.yesterday(before: day(0), checkIns: [], calendar: calendar))
    }

    func testPrefillForAPastDayUsesTheDayBeforeIt() {
        let checkIns = [DailyCheckInSnapshot(date: day(-4), restingPainAM: 2, steps: nil)]
        XCTAssertEqual(MorningPain.yesterday(before: day(-3), checkIns: checkIns, calendar: calendar), 2)
    }

    func testPrefillStaysInTheRulerRange() {
        XCTAssertEqual(MorningPain.prefill(yesterday: 14), 10)
        XCTAssertEqual(MorningPain.prefill(yesterday: -1), 0)
        XCTAssertEqual(MorningPain.range, 0...10)
    }

    func testComparisonWithYesterday() {
        XCTAssertEqual(MorningPain.comparison(3, yesterday: 3), "Same as yesterday")
        XCTAssertEqual(MorningPain.comparison(5, yesterday: 3), "+2 from yesterday")
        XCTAssertEqual(MorningPain.comparison(2, yesterday: 3), "\u{2212}1 from yesterday")
        XCTAssertEqual(MorningPain.comparison(2, yesterday: nil), "")
        XCTAssertEqual(MorningPain.comparison(nil, yesterday: 3), "Not recorded")
        // An earlier day compares with the day before it.
        XCTAssertEqual(MorningPain.comparison(3, yesterday: 3, isToday: false), "Same as the day before")
        XCTAssertEqual(MorningPain.comparison(4, yesterday: 3, isToday: false), "+1 from the day before")
    }
}
