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
        XCTAssertEqual(readout.headline, "You're doing well.")
        XCTAssertEqual(readout.detail, "Volume is up and pain is holding steady.")
    }

    func testVolumeUpPainDownIsDoingWell() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [5, 4, 4, 2, 2, 2],
                volume: [600, 600, 600, 1100, 1100, 1100]
            )
        )
        XCTAssertEqual(readout.tone, .positive)
        XCTAssertEqual(readout.headline, "You're doing well.")
        XCTAssertEqual(readout.detail, "You're loading more and pain is easing.")
    }

    func testVolumeUpPainUpIsCaution() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [2, 2, 2, 4, 4, 4],
                volume: [700, 700, 700, 1400, 1400, 1400]
            )
        )
        XCTAssertEqual(readout.tone, .caution)
        XCTAssertEqual(readout.headline, "Worth a closer look.")
        XCTAssertEqual(readout.detail, "Volume is up, and pain is climbing with it.")
    }

    func testVolumeDownPainUpIsCaution() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [2, 2, 2, 4, 4, 5],
                volume: [1400, 1400, 1400, 400, 400, 400]
            )
        )
        XCTAssertEqual(readout.tone, .caution)
        XCTAssertEqual(readout.headline, "Worth a closer look.")
        XCTAssertEqual(readout.detail, "Pain is rising while training is quieter.")
    }

    func testVolumeFlatPainUpIsCaution() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [2, 2, 2, 4, 4, 4],
                volume: [1000, 1000, 1000, 1000, 1000, 1050]
            )
        )
        XCTAssertEqual(readout.tone, .caution)
        XCTAssertEqual(readout.headline, "Worth a closer look.")
        XCTAssertEqual(readout.detail, "Pain is rising while training is quieter.")
    }

    func testNotEnoughDataIsQuiet() {
        let readout = ProgressInterpretation.classify(
            points: points(pain: [3, nil], volume: [nil, nil])
        )
        XCTAssertEqual(readout.tone, .insufficient)
        XCTAssertEqual(readout.headline, "Not enough days yet to read this window.")
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
        XCTAssertEqual(readout.headline, "Pain is easing.")
        XCTAssertEqual(readout.detail, "Log a few sessions and the load story will show up too.")
    }

    func testPainOnlyFlatIsPartial() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [3, 3, 3, 3, 3, 3],
                volume: [nil, nil, 900, nil, nil, nil]
            )
        )
        XCTAssertEqual(readout.tone, .partial)
        XCTAssertEqual(readout.headline, "Pain is holding steady.")
        XCTAssertEqual(readout.detail, "Session volume will tell the rest of the story.")
    }

    func testPainOnlyUpIsPartial() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [2, 2, 2, 4, 4, 4],
                volume: [nil, nil, nil, nil, nil, nil]
            )
        )
        XCTAssertEqual(readout.tone, .partial)
        XCTAssertEqual(readout.headline, "Pain is creeping up.")
        XCTAssertEqual(readout.detail, "That's worth watching. Volume logs will fill this in.")
    }

    func testVolumeOnlyUpIsPartial() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [nil, nil, 3, nil, nil, nil],
                volume: [500, 500, 500, 1200, 1200, 1200]
            )
        )
        XCTAssertEqual(readout.tone, .partial)
        XCTAssertEqual(readout.headline, "You're loading more.")
        XCTAssertEqual(readout.detail, "Morning scores will tell you if it's sitting well.")
    }

    func testVolumeOnlyDownIsPartial() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [nil, nil, nil, nil, nil, nil],
                volume: [1400, 1400, 1400, 400, 400, 400]
            )
        )
        XCTAssertEqual(readout.tone, .partial)
        XCTAssertEqual(readout.headline, "Volume is quiet this window.")
        XCTAssertEqual(readout.detail, "Pain logs will fill in the picture.")
    }

    func testBothFlatIsSteady() {
        let readout = ProgressInterpretation.classify(
            points: points(
                pain: [3, 3, 3, 3, 3, 3],
                volume: [1000, 1000, 1000, 1000, 1000, 1040]
            )
        )
        XCTAssertEqual(readout.tone, .steady)
        XCTAssertEqual(readout.headline, "A steady window.")
        XCTAssertEqual(readout.detail, "Pain and volume are both holding.")
    }
}
