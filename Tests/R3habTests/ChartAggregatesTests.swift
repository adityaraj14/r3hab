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

    func testVolumeSeriesSumsSameDayAndFillsGaps() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let sessions: [SessionLoadSnapshot] = [
            SessionLoadSnapshot(date: day(-2, from: today), volume: 840),
            SessionLoadSnapshot(date: day(-2, from: today), volume: 560),
            SessionLoadSnapshot(date: day(0, from: today), volume: 1120)
        ]

        let series = ChartMetricBuilder.volumeSeries(
            sessions: sessions,
            dayCount: 3,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(series.count, 3)
        XCTAssertEqual(series[0].value, 1400)
        XCTAssertNil(series[1].value)
        XCTAssertEqual(series[2].value, 1120)
    }

    func testExplorePointsMapsAMPainAndVolume() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let checkIns = [
            DailyMetricSnapshot(
                date: today,
                restingPainAM: 3,
                dailyPainPM: 4,
                steps: nil
            )
        ]
        let sessions = [
            SessionLoadSnapshot(date: today, volume: 1680)
        ]
        let points = ChartMetricBuilder.explorePoints(
            checkIns: checkIns,
            sessions: sessions,
            dayCount: 1,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].pain, 3.5)
        XCTAssertEqual(points[0].morningPain, 3)
        XCTAssertEqual(points[0].eveningPain, 4)
        XCTAssertEqual(points[0].volume, 1680)
    }

    func testAveragedDailyPainUsesLoggedSidesOnly() {
        XCTAssertEqual(ChartMetricBuilder.averagedDailyPain(morning: 3, evening: 5), 4)
        XCTAssertEqual(ChartMetricBuilder.averagedDailyPain(morning: 3, evening: 4), 3.5)
        XCTAssertEqual(ChartMetricBuilder.averagedDailyPain(morning: 2, evening: nil), 2)
        XCTAssertEqual(ChartMetricBuilder.averagedDailyPain(morning: nil, evening: 6), 6)
        XCTAssertNil(ChartMetricBuilder.averagedDailyPain(morning: nil, evening: nil))
    }

    func testExplorePointsAveragesMorningAndEveningPain() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let checkIns = [
            DailyMetricSnapshot(date: day(-3, from: today), restingPainAM: 2, dailyPainPM: 4, steps: nil),
            DailyMetricSnapshot(date: day(-2, from: today), restingPainAM: 5, dailyPainPM: nil, steps: nil),
            DailyMetricSnapshot(date: day(-1, from: today), restingPainAM: nil, dailyPainPM: 7, steps: nil),
            DailyMetricSnapshot(date: today, restingPainAM: nil, dailyPainPM: nil, steps: 1000)
        ]
        let points = ChartMetricBuilder.explorePoints(
            checkIns: checkIns,
            sessions: [],
            dayCount: 4,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(points[0].pain, 3)
        XCTAssertEqual(points[0].morningPain, 2)
        XCTAssertEqual(points[0].eveningPain, 4)
        XCTAssertEqual(points[1].pain, 5)
        XCTAssertEqual(points[1].morningPain, 5)
        XCTAssertNil(points[1].eveningPain)
        XCTAssertEqual(points[2].pain, 7)
        XCTAssertNil(points[2].morningPain)
        XCTAssertEqual(points[2].eveningPain, 7)
        XCTAssertNil(points[3].pain)
        XCTAssertNil(points[3].morningPain)
        XCTAssertNil(points[3].eveningPain)
    }

    func testExplorePointsMapsSessionVolumeOntoTheDay() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let points = ChartMetricBuilder.explorePoints(
            checkIns: [],
            sessions: [
                SessionLoadSnapshot(date: today, volume: 2450)
            ],
            dayCount: 1,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(points[0].volume, 2450)
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
        let sessions = [
            SessionLoadSnapshot(date: ymd(2026, 7, 25), volume: 360),
            SessionLoadSnapshot(date: ymd(2026, 8, 10), volume: 480)
        ]

        let month = ChartMetricBuilder.explorePoints(
            checkIns: checkIns,
            sessions: sessions,
            dayCount: 28,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(month.count, 28)
        XCTAssertEqual(calendar.startOfDay(for: month[0].date), ymd(2026, 8, 7))
        XCTAssertEqual(calendar.startOfDay(for: month[27].date), ymd(2026, 9, 3))

        let byKey = Dictionary(uniqueKeysWithValues: month.map { ($0.dayKey, $0) })
        XCTAssertEqual(byKey[CalendarDay.dayKey(ymd(2026, 8, 7), calendar: calendar)]?.pain, 4)
        XCTAssertEqual(byKey[CalendarDay.dayKey(ymd(2026, 8, 20), calendar: calendar)]?.pain, 3)
        XCTAssertEqual(byKey[CalendarDay.dayKey(ymd(2026, 9, 3), calendar: calendar)]?.pain, 2)
        XCTAssertEqual(byKey[CalendarDay.dayKey(ymd(2026, 8, 10), calendar: calendar)]?.volume, 480)
        XCTAssertNil(byKey[CalendarDay.dayKey(ymd(2026, 7, 20), calendar: calendar)])
        XCTAssertNil(byKey[CalendarDay.dayKey(ymd(2026, 7, 25), calendar: calendar)])

        let emptyInterior = byKey[CalendarDay.dayKey(ymd(2026, 8, 15), calendar: calendar)]
        XCTAssertNotNil(emptyInterior)
        XCTAssertNil(emptyInterior?.pain)
        XCTAssertNil(emptyInterior?.volume)

        let week = ChartMetricBuilder.explorePoints(
            checkIns: checkIns,
            sessions: sessions,
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
                pain: 2,
                volume: 560
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
        XCTAssertEqual(tapped?.pain, 2)
        XCTAssertEqual(tapped?.volume, 560)
    }

    func testExplorePointsSkipsUnloggedAfterPain() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let points = ChartMetricBuilder.explorePoints(
            checkIns: [],
            sessions: [],
            dayCount: 1,
            today: today,
            calendar: calendar,
            sessionPains: [
                SessionPainSnapshot(date: today, painDuring: 3, painAfter: PainScore.notLogged)
            ]
        )
        XCTAssertEqual(points[0].duringPain, 3)
        XCTAssertNil(points[0].afterPain)
    }

    func testOutcomeMixAndCleanStreak() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let sessions = [
            SessionOutcomeSnapshot(date: day(-3, from: today), createdAt: day(-3, from: today), response24h: .worse),
            SessionOutcomeSnapshot(date: day(-2, from: today), createdAt: day(-2, from: today), response24h: .better),
            SessionOutcomeSnapshot(date: day(-1, from: today), createdAt: day(-1, from: today), response24h: .same),
            SessionOutcomeSnapshot(date: today, createdAt: today, response24h: .pending)
        ]
        let mix = ChartMetricBuilder.outcomeMix(
            sessions: sessions,
            dayCount: 4,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(mix.better, 1)
        XCTAssertEqual(mix.same, 1)
        XCTAssertEqual(mix.worse, 1)
        XCTAssertEqual(mix.pending, 1)
        XCTAssertEqual(mix.cleanStreak, 2)

        let points = ChartMetricBuilder.outcomePoints(
            sessions: sessions,
            dayCount: 4,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(points.count, 4)
        XCTAssertEqual(points[0].worse, 1)
        XCTAssertEqual(points[3].pending, 1)
    }

    func testProgressDayRangeFixedWindowsAndAllFromEarliest() {
        let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16))!
        func ymd(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }

        XCTAssertEqual(
            ProgressDayRange.days7.dayCount(
                checkInDates: [ymd(2026, 1, 1)],
                sessionDates: [],
                today: today,
                calendar: calendar
            ),
            7
        )
        XCTAssertEqual(
            ProgressDayRange.days28.dayCount(
                checkInDates: [],
                sessionDates: [ymd(2026, 1, 1)],
                today: today,
                calendar: calendar
            ),
            28
        )
        XCTAssertEqual(
            ProgressDayRange.days90.dayCount(
                checkInDates: [ymd(2025, 1, 1)],
                sessionDates: [ymd(2025, 6, 1)],
                today: today,
                calendar: calendar
            ),
            90
        )

        let allFromAugust = ProgressDayRange.all.dayCount(
            checkInDates: [ymd(2026, 8, 18)],
            sessionDates: [ymd(2026, 8, 20)],
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(allFromAugust, 30)

        let capped = ProgressDayRange.all.dayCount(
            checkInDates: [ymd(2023, 1, 1)],
            sessionDates: [],
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(capped, ProgressDayRange.allCapDays)
        XCTAssertEqual(ProgressDayRange.allCapDays, 730)
        XCTAssertEqual(ProgressDayRange.days90.chartVisibleDays(windowDays: 90), 90)
        XCTAssertEqual(ProgressDayRange.all.chartVisibleDays(windowDays: 400), 90)
    }

    func testExplorePoints90DayWindowKeepsInteriorHistory() {
        let today = calendar.date(from: DateComponents(year: 2026, month: 9, day: 16))!
        func ymd(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }

        let checkIns = [
            DailyMetricSnapshot(date: ymd(2026, 6, 1), restingPainAM: 5, dailyPainPM: nil, steps: nil),
            DailyMetricSnapshot(date: ymd(2026, 7, 20), restingPainAM: 4, dailyPainPM: nil, steps: nil),
            DailyMetricSnapshot(date: ymd(2026, 8, 20), restingPainAM: 3, dailyPainPM: nil, steps: nil),
            DailyMetricSnapshot(date: today, restingPainAM: 2, dailyPainPM: nil, steps: nil)
        ]
        let sessions = [
            SessionLoadSnapshot(date: ymd(2026, 7, 25), volume: 360),
            SessionLoadSnapshot(date: ymd(2026, 8, 10), volume: 480)
        ]

        let quarter = ChartMetricBuilder.explorePoints(
            checkIns: checkIns,
            sessions: sessions,
            dayCount: 90,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(quarter.count, 90)
        XCTAssertEqual(calendar.startOfDay(for: quarter[0].date), ymd(2026, 6, 19))
        XCTAssertEqual(calendar.startOfDay(for: quarter[89].date), today)

        let byKey = Dictionary(uniqueKeysWithValues: quarter.map { ($0.dayKey, $0) })
        XCTAssertEqual(byKey[CalendarDay.dayKey(ymd(2026, 7, 20), calendar: calendar)]?.pain, 4)
        XCTAssertEqual(byKey[CalendarDay.dayKey(ymd(2026, 8, 20), calendar: calendar)]?.pain, 3)
        XCTAssertEqual(byKey[CalendarDay.dayKey(ymd(2026, 8, 10), calendar: calendar)]?.volume, 480)
        XCTAssertNil(byKey[CalendarDay.dayKey(ymd(2026, 6, 1), calendar: calendar)])
    }

    func testConsistencyCountsOnlyWindowDays() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let checkIns = [
            DailyMetricSnapshot(date: day(-10, from: today), restingPainAM: 4, dailyPainPM: nil, steps: nil),
            DailyMetricSnapshot(date: day(-1, from: today), restingPainAM: 2, dailyPainPM: 3, steps: 5000),
            DailyMetricSnapshot(date: today, restingPainAM: nil, dailyPainPM: 2, steps: nil)
        ]
        let sessions = [
            SessionOutcomeSnapshot(date: day(-10, from: today), createdAt: day(-10, from: today), response24h: .better),
            SessionOutcomeSnapshot(date: today, createdAt: today, response24h: .pending)
        ]
        let summary = ChartMetricBuilder.consistency(
            checkIns: checkIns,
            sessions: sessions,
            dayCount: 3,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(summary.windowDays, 3)
        XCTAssertEqual(summary.checkInDays, 2)
        XCTAssertEqual(summary.morningDays, 1)
        XCTAssertEqual(summary.sessionDays, 1)
        XCTAssertEqual(summary.sessionCount, 1)
    }
}
