import XCTest
@testable import R3hab

final class SessionVolumeTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func day(_ offset: Int, from today: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: today))!
    }

    private func workPair(reps: Int, loadLbs: Double, rightLoadLbs: Double? = nil) -> [ResistanceSet] {
        SessionSummary.makePair(
            reps: reps,
            loadLbs: loadLbs,
            holdSeconds: nil,
            isWarmup: false,
            rightLoadLbs: rightLoadLbs
        )
    }

    func testSameMaxLoadDifferentSetsProduceDifferentVolumes() {
        let threeSets = (0..<3).flatMap { _ in workPair(reps: 8, loadLbs: 35) }
        let fiveSets = (0..<5).flatMap { _ in workPair(reps: 8, loadLbs: 35) }

        XCTAssertEqual(ResistanceMath.chartVolume(threeSets), 1680)
        XCTAssertEqual(ResistanceMath.chartVolume(fiveSets), 2800)
        XCTAssertEqual(ResistanceMath.chartMaxLoad(work: threeSets), 35)
        XCTAssertEqual(ResistanceMath.chartMaxLoad(work: fiveSets), 35)
        XCTAssertNotEqual(
            ResistanceMath.chartVolume(threeSets),
            ResistanceMath.chartVolume(fiveSets)
        )
    }

    func testWarmupsAreExcludedFromSessionVolume() {
        let warmup = SessionSummary.makePair(reps: 10, loadLbs: 35, holdSeconds: nil, isWarmup: true)
        let work = (0..<3).flatMap { _ in workPair(reps: 8, loadLbs: 35) }
        XCTAssertEqual(ResistanceMath.chartVolume(warmup + work), 1680)
        XCTAssertNil(ResistanceMath.chartVolume(warmup))
    }

    func testHoldSecondsDoNotEnterVolume() {
        let holds = [
            ResistanceSet(reps: 4, loadLbs: 35, holdSeconds: 45, isWarmup: false, side: .left),
            ResistanceSet(reps: 4, loadLbs: 35, holdSeconds: 45, isWarmup: false, side: .right)
        ]
        XCTAssertEqual(ResistanceMath.chartVolume(holds), 280)
    }

    func testLeftAndRightWorkRowsBothCount() {
        let split = workPair(reps: 8, loadLbs: 35, rightLoadLbs: 30)
        XCTAssertEqual(ResistanceMath.chartVolume(split), 520)
    }

    func testMultipleSessionsOnOneDaySum() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let series = ChartMetricBuilder.volumeSeries(
            sessions: [
                SessionLoadSnapshot(date: today, volume: ResistanceMath.chartVolume(
                    (0..<3).flatMap { _ in workPair(reps: 8, loadLbs: 35) }
                )),
                SessionLoadSnapshot(date: today, volume: ResistanceMath.chartVolume(
                    (0..<2).flatMap { _ in workPair(reps: 8, loadLbs: 35) }
                ))
            ],
            dayCount: 1,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(series[0].value, 2800)
    }

    func testMissingDaysRemainGaps() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let series = ChartMetricBuilder.volumeSeries(
            sessions: [
                SessionLoadSnapshot(date: day(-2, from: today), volume: 1680),
                SessionLoadSnapshot(date: today, volume: 2240)
            ],
            dayCount: 3,
            today: today,
            calendar: calendar
        )
        XCTAssertEqual(series.map(\.value), [1680, nil, 2240])
    }

    func testLegacyFallbackUsesSetRepsAndLoad() {
        let session = makeSession(sets: 3, reps: 8, loadLbs: 35)
        XCTAssertEqual(session.chartVolume, 840)
        XCTAssertNil(session.resistanceSetsJSON)
    }

    func testLegacyLoadOnlyLeavesAChartGap() {
        let session = makeSession(sets: nil, reps: nil, loadLbs: 35)
        XCTAssertNil(session.chartVolume)

        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let series = ChartMetricBuilder.volumeSeries(
            sessions: [SessionLoadSnapshot(date: today, volume: session.chartVolume)],
            dayCount: 1,
            today: today,
            calendar: calendar
        )
        XCTAssertNil(series[0].value)
    }

    func testVolumeCopyFormatsGroupedLbReps() {
        XCTAssertEqual(VolumeCopy.labeled(2450), "2,450 lb·reps")
    }

    private func makeSession(sets: Int?, reps: Int?, loadLbs: Double?) -> TrainingSession {
        TrainingSession(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            phase: .cHeavySlowResistance,
            sessionType: .hsrStrength,
            whatIDid: "Seated leg extension",
            painDuring: 2,
            sets: sets,
            reps: reps,
            loadLbs: loadLbs,
            calendar: calendar
        )
    }
}
