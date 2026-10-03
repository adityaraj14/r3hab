import XCTest
@testable import R3hab

final class SessionSummaryTests: XCTestCase {
    func testDisplayTitleTakesHeadBeforeDotSeparator() {
        let title = SessionSummary.displayTitle(
            whatIDid: "Seated leg extension · WU 2×30s @ 15 lbs · 8r L @ 15 lbs, 8r R @ 15 lbs"
        )
        XCTAssertEqual(title, "Seated leg extension")
    }

    func testDisplayTitleFallsBackWhenEmpty() {
        XCTAssertEqual(SessionSummary.displayTitle(whatIDid: "   "), "Session")
    }

    func testLooksStructuredWhatIDid() {
        XCTAssertTrue(SessionSummary.looksStructuredWhatIDid("Seated leg extension · 4×30s @ 35 lbs"))
        XCTAssertTrue(SessionSummary.looksStructuredWhatIDid("3x8 @ 20 lbs both"))
        XCTAssertFalse(SessionSummary.looksStructuredWhatIDid("easy bike and a walk"))
    }

    func testLastSessionLineUsesWorkDoseAndPain() {
        let holds = SessionSummary.makePair(
            reps: 4,
            loadLbs: 35,
            holdSeconds: 30,
            isWarmup: false
        )
        XCTAssertEqual(
            SessionSummary.lastSessionLine(whatIDid: "Seated leg extension", sets: holds, painDuring: 2),
            "Last session: 4×30s @ 35 lb. Pain 2."
        )
    }

    func testLastSessionLineDropsWarmupAndBothSuffix() {
        let warmup = [ResistanceSet(reps: 2, loadLbs: 15, holdSeconds: 30, isWarmup: true)]
        let work = (0..<3).flatMap { _ in
            SessionSummary.makePair(reps: 8, loadLbs: 15, holdSeconds: nil, isWarmup: false)
        }
        XCTAssertEqual(
            SessionSummary.lastSessionLine(whatIDid: "Seated leg extension", sets: warmup + work, painDuring: 1),
            "Last session: 3×8 @ 15 lb. Pain 1."
        )
    }

    func testLastSessionLineOmitsPainWhenNotLogged() {
        XCTAssertEqual(
            SessionSummary.lastSessionLine(whatIDid: "Easy bike", sets: [], painDuring: PainScore.notLogged),
            "Last session: Easy bike"
        )
    }

    func testGroupsAlternatingLeftRightIntoPairs() {
        let sets = (0..<3).flatMap { _ in
            SessionSummary.makePair(reps: 8, loadLbs: 15, holdSeconds: nil, isWarmup: false)
        }
        let pairs = SessionSummary.groupWorkSets(sets)
        XCTAssertEqual(pairs.count, 3)
        XCTAssertEqual(pairs[0].reps, 8)
        XCTAssertEqual(pairs[0].leftLoad, 15)
        XCTAssertEqual(pairs[0].rightLoad, 15)
        XCTAssertTrue(pairs[0].loadsMatch)
    }

    func testCompactResistanceCollapsesMatchedPairs() {
        let warmup = [ResistanceSet(reps: 2, loadLbs: 15, holdSeconds: 30, isWarmup: true)]
        let work = (0..<3).flatMap { _ in
            SessionSummary.makePair(reps: 8, loadLbs: 15, holdSeconds: nil, isWarmup: false)
        }
        let compact = SessionSummary.compactResistance(warmup + work)
        XCTAssertEqual(compact, "3×8 @ 15 lb both · Warm-up 2×30s @ 15 lb")
    }

    func testCompactResistanceShowsSplitLoads() {
        let work = SessionSummary.makePair(
            reps: 8,
            loadLbs: 15,
            holdSeconds: nil,
            isWarmup: false,
            rightLoadLbs: 20
        )
        let compact = SessionSummary.compactResistance(work)
        XCTAssertEqual(compact, "8 Left @ 15 lb / Right @ 20 lb")
    }

    func testInferUnilateralWhenLoadsDiffer() {
        let work = SessionSummary.makePair(
            reps: 8,
            loadLbs: 15,
            holdSeconds: nil,
            isWarmup: false,
            rightLoadLbs: 20
        )
        XCTAssertEqual(SessionSummary.inferredLaterality(workSets: work), .unilateral)
    }

    func testInferBilateralWhenLoadsMatch() {
        let work = (0..<3).flatMap { _ in
            SessionSummary.makePair(reps: 8, loadLbs: 15, holdSeconds: nil, isWarmup: false)
        }
        XCTAssertEqual(SessionSummary.inferredLaterality(workSets: work), .bilateral)
    }

    func testHistoryListNumbersWorkSetsAndMutesWarmupsFirst() {
        let warmup = [ResistanceSet(reps: 1, loadLbs: 30, holdSeconds: 30, isWarmup: true)]
        let work = SessionSummary.makePair(reps: 8, loadLbs: 30, holdSeconds: nil, isWarmup: false)
            + SessionSummary.makePair(reps: 8, loadLbs: 35, holdSeconds: nil, isWarmup: false)
        let list = SessionSummary.historyResistanceList(warmup + work)
        XCTAssertEqual(list?.header, "2 sets · 1 warm-up")
        XCTAssertEqual(list?.rows.map(\.kind.label), ["Warm-up", "1", "2"])
        XCTAssertEqual(list?.rows.map(\.dose), ["30s", "8", "8"])
        XCTAssertEqual(list?.rows.map(\.load), ["@ 30 lb", "@ 30 lb", "@ 35 lb"])
        XCTAssertEqual(list?.rows.map(\.laterality), ["both", "both", "both"])
        XCTAssertEqual(list?.rows[0].spoken, "Warm-up, 30 seconds, at 30 lb, both")
        XCTAssertEqual(list?.rows[1].spoken, "Set 1, 8 reps, at 30 lb, both")
        XCTAssertEqual(list?.rows[2].spoken, "Set 2, 8 reps, at 35 lb, both")
        XCTAssertTrue(list?.rows[0].isWarmup == true)
    }

    func testHistoryListShowsSplitLoadsWithoutBoth() {
        let work = SessionSummary.makePair(
            reps: 8,
            loadLbs: 35,
            holdSeconds: nil,
            isWarmup: false,
            rightLoadLbs: 30
        )
        let list = SessionSummary.historyResistanceList(work)
        XCTAssertEqual(list?.header, "1 set")
        XCTAssertEqual(list?.rows[0].dose, "8")
        XCTAssertEqual(list?.rows[0].load, "@ Left 35 lb / Right 30 lb")
        XCTAssertNil(list?.rows[0].laterality)
        XCTAssertEqual(list?.rows[0].spoken, "Set 1, 8 reps, at left 35, right 30")
    }

    func testHistoryListOverflowShowsFirstFourPlusRemainder() {
        let work = (0..<7).flatMap { index in
            SessionSummary.makePair(
                reps: 8,
                loadLbs: Double(20 + index),
                holdSeconds: nil,
                isWarmup: false
            )
        }
        let list = SessionSummary.historyResistanceList(work)
        XCTAssertEqual(list?.header, "7 sets")
        XCTAssertEqual(list?.hiddenWorkCount, 3)
        XCTAssertEqual(list?.rows.map(\.kind.label), ["1", "2", "3", "4", "+3"])
        XCTAssertEqual(list?.rows.last?.spoken, "3 more sets")
    }

    func testHistoryListOmitsZeroWarmupsFromHeader() {
        let work = SessionSummary.makePair(reps: 8, loadLbs: 15, holdSeconds: nil, isWarmup: false)
        let list = SessionSummary.historyResistanceList(work)
        XCTAssertEqual(list?.header, "1 set")
        XCTAssertEqual(list?.warmupCount, 0)
    }

    func testHistoryListKeepsFiveWorkSetsWithoutOverflow() {
        let work = (0..<5).flatMap { _ in
            SessionSummary.makePair(reps: 8, loadLbs: 15, holdSeconds: nil, isWarmup: false)
        }
        let list = SessionSummary.historyResistanceList(work)
        XCTAssertEqual(list?.hiddenWorkCount, 0)
        XCTAssertEqual(list?.rows.count, 5)
        XCTAssertEqual(list?.rows.map(\.kind.label), ["1", "2", "3", "4", "5"])
    }

    func testApplyLateralityUnifiesLoadsWhenSwitchingToBilateral() {
        let work = SessionSummary.makePair(
            reps: 8,
            loadLbs: 15,
            holdSeconds: nil,
            isWarmup: false,
            rightLoadLbs: 20
        )
        let unified = SessionSummary.applyLaterality(.bilateral, to: work)
        XCTAssertEqual(unified.count, 2)
        XCTAssertEqual(unified[0].loadLbs, 15)
        XCTAssertEqual(unified[1].loadLbs, 15)
        XCTAssertEqual(unified[0].side, .left)
        XCTAssertEqual(unified[1].side, .right)
    }
}
