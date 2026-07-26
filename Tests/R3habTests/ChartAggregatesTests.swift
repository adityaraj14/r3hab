import XCTest
@testable import R3hab

final class ChartAggregatesTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func day(_ offset: Int, from today: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: today))!
    }

    func testLowerBackSeriesFillsGapsAndMapsValues() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let rows: [DailyMetricSnapshot] = [
            DailyMetricSnapshot(
                date: day(-2, from: today),
                restingPainAM: 2,
                dailyPainPM: 3,
                lowerBackPainAM: 4,
                lowerBackPainPM: 5,
                steps: 5000
            ),
            DailyMetricSnapshot(
                date: day(0, from: today),
                restingPainAM: 1,
                dailyPainPM: 2,
                lowerBackPainAM: 3,
                lowerBackPainPM: nil,
                steps: 6000
            )
        ]

        let backAM = ChartMetricBuilder.series(
            rows: rows,
            metric: .lowerBackAM,
            dayCount: 3,
            today: today,
            calendar: calendar
        )
        // dayCount 3 → offsets 2, 1, 0 (oldest → today)
        XCTAssertEqual(backAM.count, 3)
        XCTAssertEqual(backAM[0].value, 4)
        XCTAssertNil(backAM[1].value)
        XCTAssertEqual(backAM[2].value, 3)

        let backPM = ChartMetricBuilder.series(
            rows: rows,
            metric: .lowerBackPM,
            dayCount: 3,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(backPM[0].value, 5)
        XCTAssertNil(backPM[1].value)
        XCTAssertNil(backPM[2].value)
    }

    func testKneeSeriesUnchangedAlongsideBack() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let rows = [
            DailyMetricSnapshot(
                date: today,
                restingPainAM: 2,
                dailyPainPM: 3,
                lowerBackPainAM: 9,
                lowerBackPainPM: 8,
                steps: nil
            )
        ]
        let knee = ChartMetricBuilder.series(
            rows: rows,
            metric: .restingAM,
            dayCount: 1,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(knee.first?.value, 2)
    }
}
