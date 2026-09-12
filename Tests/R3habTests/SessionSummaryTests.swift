import XCTest
@testable import R3hab

final class SessionSummaryTests: XCTestCase {
    func testDisplayTitleTakesHeadBeforeDotSeparator() {
        let title = SessionSummary.displayTitle(
            whatIDid: "Seated extension · WU 2×30s @ 15 lbs · 8r L @ 15 lbs, 8r R @ 15 lbs"
        )
        XCTAssertEqual(title, "Seated extension")
    }

    func testDisplayTitleFallsBackWhenEmpty() {
        XCTAssertEqual(SessionSummary.displayTitle(whatIDid: "   "), "Session")
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
        XCTAssertEqual(compact, "3×8 @ 15 lbs both · WU 2×30s @ 15 lbs")
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
        XCTAssertEqual(compact, "8 L @ 15 lbs / R @ 20 lbs")
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
