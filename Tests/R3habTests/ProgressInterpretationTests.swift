import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class ProgressInterpretationTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func points(
        pain: [Double?],
        volume: [Double?],
        from today: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> [DayExplorePoint] {
        let start = calendar.startOfDay(for: today)
        return zip(pain, volume).enumerated().map { index, pair in
            let date = calendar.date(byAdding: .day, value: index, to: start)!
            return DayExplorePoint(
                dayKey: CalendarDay.dayKey(date, calendar: calendar),
                date: date,
                pain: pair.0,
                volume: pair.1
            )
        }
    }

    func testVolumeUpPainFlatIsDoingWell() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [3, 3, 3, 3, 3, 3],
                volume: [800, 800, 800, 1200, 1200, 1200]
            )
        )
        XCTAssertEqual(readout.tone, .positive)
        XCTAssertEqual(readout.headline, "This result is good.")
        XCTAssertEqual(readout.detail, "The load is higher and the pain stays the same.")
    }

    func testVolumeUpPainDownIsDoingWell() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [5, 4, 4, 2, 2, 2],
                volume: [600, 600, 600, 1100, 1100, 1100]
            )
        )
        XCTAssertEqual(readout.tone, .positive)
        XCTAssertEqual(readout.headline, "This result is good.")
        XCTAssertEqual(readout.detail, "The load is higher and the pain decreases.")
    }

    func testVolumeUpPainUpIsCaution() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [2, 2, 2, 4, 4, 4],
                volume: [700, 700, 700, 1400, 1400, 1400]
            )
        )
        XCTAssertEqual(readout.tone, .caution)
        XCTAssertEqual(readout.headline, "Examine this result.")
        XCTAssertEqual(readout.detail, "The load is higher and the pain increases with it.")
    }

    func testVolumeDownPainUpIsCaution() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [2, 2, 2, 4, 4, 5],
                volume: [1400, 1400, 1400, 400, 400, 400]
            )
        )
        XCTAssertEqual(readout.tone, .caution)
        XCTAssertEqual(readout.headline, "Examine this result.")
        XCTAssertEqual(readout.detail, "The pain increases and the sessions are fewer.")
    }

    func testVolumeFlatPainUpIsCaution() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [2, 2, 2, 4, 4, 4],
                volume: [1000, 1000, 1000, 1000, 1000, 1050]
            )
        )
        XCTAssertEqual(readout.tone, .caution)
        XCTAssertEqual(readout.headline, "Examine this result.")
        XCTAssertEqual(readout.detail, "The pain increases and the sessions are fewer.")
    }

    func testNotEnoughDataIsQuiet() {
        let readout = ProgressInterpretation.classify(
            points: points(pain: [3, nil], volume: [nil, nil])
        )
        XCTAssertEqual(readout.tone, .insufficient)
        XCTAssertEqual(readout.headline, "This window does not have enough days.")
        XCTAssertNil(readout.detail)
    }

    func testPainOnlyDownIsPartial() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [5, 4, 4, 2, 2, 2],
                volume: [nil, nil, nil, nil, nil, nil]
            )
        )
        XCTAssertEqual(readout.tone, .partial)
        XCTAssertEqual(readout.headline, "The pain decreases.")
        XCTAssertEqual(readout.detail, "Record more sessions to see the load.")
    }

    func testPainOnlyFlatIsPartial() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [3, 3, 3, 3, 3, 3],
                volume: [nil, nil, 900, nil, nil, nil]
            )
        )
        XCTAssertEqual(readout.tone, .partial)
        XCTAssertEqual(readout.headline, "The pain stays the same.")
        XCTAssertEqual(readout.detail, "The session volume shows the rest of the result.")
    }

    func testPainOnlyUpIsPartial() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [2, 2, 2, 4, 4, 4],
                volume: [nil, nil, nil, nil, nil, nil]
            )
        )
        XCTAssertEqual(readout.tone, .partial)
        XCTAssertEqual(readout.headline, "The pain increases.")
        XCTAssertEqual(readout.detail, "Examine this pain. Record the session volume.")
    }

    func testVolumeOnlyUpIsPartial() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [nil, nil, 3, nil, nil, nil],
                volume: [500, 500, 500, 1200, 1200, 1200]
            )
        )
        XCTAssertEqual(readout.tone, .partial)
        XCTAssertEqual(readout.headline, "The load is higher.")
        XCTAssertEqual(readout.detail, "The morning pain shows if the load is acceptable.")
    }

    func testVolumeOnlyDownIsPartial() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [nil, nil, nil, nil, nil, nil],
                volume: [1400, 1400, 1400, 400, 400, 400]
            )
        )
        XCTAssertEqual(readout.tone, .partial)
        XCTAssertEqual(readout.headline, "The session volume is low in this window.")
        XCTAssertEqual(readout.detail, "Record the pain to complete this window.")
    }

    func testBothFlatIsSteady() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [3, 3, 3, 3, 3, 3],
                volume: [1000, 1000, 1000, 1000, 1000, 1040]
            )
        )
        XCTAssertEqual(readout.tone, .steady)
        XCTAssertEqual(readout.headline, "This window is stable.")
        XCTAssertEqual(readout.detail, "The pain and the load stay the same.")
    }
}
