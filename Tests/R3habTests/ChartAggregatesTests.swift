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

    func testExplorePointsMapsAMPainAndSideLoads() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let checkIns = [
            DailyMetricSnapshot(
                date: today,
                restingPainAM: 3,
                dailyPainPM: 4,
                steps: nil
            )
        ]
        let loads = [
            SessionSideLoadSnapshot(
                date: today,
                leftMaxLbs: 45,
                rightMaxLbs: 40,
                unspecifiedMaxLbs: 45
            )
        ]
        let points = ChartMetricBuilder.explorePoints(
            checkIns: checkIns,
            sideLoads: loads,
            dayCount: 1,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].amPain, 3)
        XCTAssertEqual(points[0].leftLoadLbs, 45)
        XCTAssertEqual(points[0].rightLoadLbs, 40)
    }

    func testExplorePointsMapsUnspecifiedLoadOntoBothSides() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let points = ChartMetricBuilder.explorePoints(
            checkIns: [],
            sideLoads: [
                SessionSideLoadSnapshot(
                    date: today,
                    leftMaxLbs: nil,
                    rightMaxLbs: nil,
                    unspecifiedMaxLbs: 30
                )
            ],
            dayCount: 1,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(points[0].leftLoadLbs, 30)
        XCTAssertEqual(points[0].rightLoadLbs, 30)
    }

    func testExplorePoints28DayWindowKeepsInteriorHistory() {
        let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        func ymd(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }

        let checkIns = [
            DailyMetricSnapshot(date: ymd(2026, 7, 20), restingPainAM: 5, dailyPainPM: nil, steps: nil),
            DailyMetricSnapshot(date: ymd(2026, 8, 7), restingPainAM: 4, dailyPainPM: nil, steps: nil),
            DailyMetricSnapshot(date: ymd(2026, 8, 20), restingPainAM: 3, dailyPainPM: nil, steps: nil),
            DailyMetricSnapshot(date: ymd(2026, 9, 3), restingPainAM: 2, dailyPainPM: nil, steps: nil)
        ]
        let loads = [
            SessionSideLoadSnapshot(
                date: ymd(2026, 7, 25),
                leftMaxLbs: 15,
                rightMaxLbs: 15,
                unspecifiedMaxLbs: 15
            ),
            SessionSideLoadSnapshot(
                date: ymd(2026, 8, 10),
                leftMaxLbs: 20,
                rightMaxLbs: 20,
                unspecifiedMaxLbs: 20
            )
        ]

        let month = ChartMetricBuilder.explorePoints(
            checkIns: checkIns,
            sideLoads: loads,
            dayCount: 28,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(month.count, 28)
        XCTAssertEqual(calendar.startOfDay(for: month[0].date), ymd(2026, 8, 7))
        XCTAssertEqual(calendar.startOfDay(for: month[27].date), ymd(2026, 9, 3))

        let byKey = Dictionary(uniqueKeysWithValues: month.map { ($0.dayKey, $0) })
        XCTAssertEqual(byKey[CalendarDay.dayKey(ymd(2026, 8, 7), calendar: calendar)]?.amPain, 4)
        XCTAssertEqual(byKey[CalendarDay.dayKey(ymd(2026, 8, 20), calendar: calendar)]?.amPain, 3)
        XCTAssertEqual(byKey[CalendarDay.dayKey(ymd(2026, 9, 3), calendar: calendar)]?.amPain, 2)
        XCTAssertEqual(byKey[CalendarDay.dayKey(ymd(2026, 8, 10), calendar: calendar)]?.leftLoadLbs, 20)
        XCTAssertNil(byKey[CalendarDay.dayKey(ymd(2026, 7, 20), calendar: calendar)])
        XCTAssertNil(byKey[CalendarDay.dayKey(ymd(2026, 7, 25), calendar: calendar)])

        let emptyInterior = byKey[CalendarDay.dayKey(ymd(2026, 8, 15), calendar: calendar)]
        XCTAssertNotNil(emptyInterior)
        XCTAssertNil(emptyInterior?.amPain)
        XCTAssertNil(emptyInterior?.leftLoadLbs)

        let week = ChartMetricBuilder.explorePoints(
            checkIns: checkIns,
            sideLoads: loads,
            dayCount: 7,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(calendar.startOfDay(for: week[0].date), ymd(2026, 8, 28))
        XCTAssertEqual(calendar.startOfDay(for: week[6].date), ymd(2026, 9, 3))

        let pm = ChartMetricBuilder.series(
            rows: checkIns,
            metric: .dailyPM,
            dayCount: 28,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(pm.count, 28)
        XCTAssertEqual(calendar.startOfDay(for: pm[0].date), ymd(2026, 8, 7))
        XCTAssertEqual(calendar.startOfDay(for: pm[27].date), ymd(2026, 9, 3))
    }

    func testDaySelectionMapsPlotXAcross28Days() {
        let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3))!
        let points: [DayExplorePoint] = (0..<28).map { offset in
            let date = calendar.date(byAdding: .day, value: offset - 27, to: today)!
            return DayExplorePoint(
                dayKey: CalendarDay.dayKey(date, calendar: calendar),
                date: date,
                amPain: 2,
                leftLoadLbs: 20,
                rightLoadLbs: 20
            )
        }

        XCTAssertEqual(
            ChartDaySelection.point(atPlotX: 0, width: 280, points: points)?.dayKey,
            points[0].dayKey
        )
        XCTAssertEqual(
            ChartDaySelection.point(atPlotX: 280, width: 280, points: points)?.dayKey,
            points[27].dayKey
        )
        XCTAssertEqual(
            ChartDaySelection.point(atPlotX: 100, width: 280, points: points)?.dayKey,
            points[10].dayKey
        )

        let tapped = ChartDaySelection.nearestPoint(to: points[5].date, in: points)
        XCTAssertEqual(tapped?.dayKey, points[5].dayKey)
        XCTAssertEqual(tapped?.amPain, 2)
        XCTAssertEqual(tapped?.leftLoadLbs, 20)
    }
}
