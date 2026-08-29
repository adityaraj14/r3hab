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

    func testKneeAMSeriesFillsGapsAndMapsValues() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let rows: [DailyMetricSnapshot] = [
            DailyMetricSnapshot(
                date: day(-2, from: today),
                restingPainAM: 4,
                dailyPainPM: 5,
                steps: 5000
            ),
            DailyMetricSnapshot(
                date: day(0, from: today),
                restingPainAM: 3,
                dailyPainPM: nil,
                steps: 6000
            )
        ]

        let kneeAM = ChartMetricBuilder.series(
            rows: rows,
            metric: .restingAM,
            dayCount: 3,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(kneeAM.count, 3)
        XCTAssertEqual(kneeAM[0].value, 4)
        XCTAssertNil(kneeAM[1].value)
        XCTAssertEqual(kneeAM[2].value, 3)

        let kneePM = ChartMetricBuilder.series(
            rows: rows,
            metric: .dailyPM,
            dayCount: 3,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(kneePM[0].value, 5)
        XCTAssertNil(kneePM[1].value)
        XCTAssertNil(kneePM[2].value)
    }

    func testKneeSeriesReadsRestingAM() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let rows = [
            DailyMetricSnapshot(
                date: today,
                restingPainAM: 2,
                dailyPainPM: 3,
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

    func testLoadSeriesTakesMaxPerDayAndFillsGaps() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let sessions: [SessionLoadSnapshot] = [
            SessionLoadSnapshot(date: day(-2, from: today), loadLbs: 20),
            SessionLoadSnapshot(date: day(-2, from: today), loadLbs: 25),
            SessionLoadSnapshot(date: day(0, from: today), loadLbs: 30)
        ]

        let series = ChartMetricBuilder.loadSeries(
            sessions: sessions,
            dayCount: 3,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(series.count, 3)
        XCTAssertEqual(series[0].value, 25)
        XCTAssertNil(series[1].value)
        XCTAssertEqual(series[2].value, 30)
    }

    func testScaledLoadMapsOntoPainDomain() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let loadPoints = [
            DayValue(dayKey: "a", date: day(-1, from: today), value: 20),
            DayValue(dayKey: "b", date: today, value: 40)
        ]
        let (scaled, maxLoad) = ChartMetricBuilder.scaledLoadSeries(loadPoints: loadPoints)
        XCTAssertEqual(maxLoad, 40)
        XCTAssertEqual(scaled[0].value, 5)
        XCTAssertEqual(scaled[1].value, 10)
    }
}
