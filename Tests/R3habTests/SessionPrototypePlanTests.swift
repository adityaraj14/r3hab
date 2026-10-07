import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class SessionPrototypePlanTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var day0: Date {
        calendar.startOfDay(for: Date(timeIntervalSince1970: 1_777_766_400))
    }

    func testEmptyHistoryPrefillsThreeByEight() {
        let draft = SessionPrototypePlan.make(
            sessions: [],
            phase: .cHeavySlowResistance,
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(draft.exerciseTitle, "Seated leg extension")
        XCTAssertEqual(draft.sessionType, .hsrStrength)
        XCTAssertEqual(draft.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: nil))
        XCTAssertEqual(draft.sets.count, 3)
        XCTAssertTrue(draft.sets.allSatisfy { $0.matchesTarget(draft.target) })
        XCTAssertEqual(draft.planLine, "3×8")
        XCTAssertFalse(draft.includeWarmup)
        XCTAssertTrue(draft.whatIDid().hasPrefix("Seated leg extension"))
    }

    func testPrefillCopiesSeatedExtensionTargetLoad() {
        let prior = session(dayOffset: -3, reps: 8, load: 45)
        let draft = SessionPrototypePlan.make(
            sessions: [prior],
            phase: .cHeavySlowResistance,
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(draft.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 45))
        XCTAssertEqual(draft.sets.count, 3)
        XCTAssertTrue(draft.sets.allSatisfy { $0.reps == 8 && $0.loadLbs == 45 })
        XCTAssertEqual(draft.planLine, "3×8 @ 45 lb")
        XCTAssertEqual(draft.stanceLabel, "Hold the load")
        let work = draft.resistanceSets().filter { !$0.isWarmup }
        XCTAssertEqual(work.count, 6)
        XCTAssertTrue(work.allSatisfy { $0.loadLbs == 45 && $0.reps == 8 })
    }

    /// TestFlight 45 bug: on an increase day, set 2 showed "Target 8 × 50 lb" (the last load).
    /// The Today card, the target, the ruler start, and the delta now use one recommended load.
    func testIncreaseDayUsesTheRecommendedLoadEverywhere() throws {
        let history = [
            session(dayOffset: -5, reps: 8, load: 50),
            session(dayOffset: -3, reps: 8, load: 50)
        ]
        let engine = ProgressionEngine.today(sessions: history, asOf: day0, calendar: calendar)
        let draft = SessionPrototypePlan.make(sessions: history, phase: .cHeavySlowResistance, asOf: day0, calendar: calendar)
        let recommended = 50 + ProgressionEngine.loadIncrementLbs
        XCTAssertEqual(draft.stanceLabel, "Increase the load")
        // Today card.
        XCTAssertEqual(engine.cardReason, "Increase the load. Try 55 lb.")
        XCTAssertEqual(engine.suggestedChangeLoadLbs, recommended)
        // Target line on each set step.
        XCTAssertEqual(draft.target.loadLbs, recommended)
        XCTAssertTrue(draft.perSetTargetLine.contains("55 lb"), draft.perSetTargetLine)
        XCTAssertFalse(draft.perSetTargetLine.contains("50 lb"), draft.perSetTargetLine)
        // Ruler start: every set opens at the recommended load, and the delta reads "Target".
        XCTAssertTrue(draft.sets.allSatisfy { $0.loadLbs == recommended })
        XCTAssertEqual(SessionPrototypePlan.loadDelta(draft.sets[1].loadLbs, target: draft.target.loadLbs), "Target")
        // Back at the last load: the delta shows the step down from the recommended load.
        XCTAssertEqual(SessionPrototypePlan.loadDelta(50, target: draft.target.loadLbs), "\u{2212}5 lb")
        // The warm-up template uses the same working load.
        let working = try XCTUnwrap(draft.target.loadLbs)
        XCTAssertEqual(draft.warmup.steps.last?.loadLbs, WarmupPlan.roundLoad(working * 0.75, step: 5))
    }

    /// A hold day keeps the last load everywhere, and the Today card names no new weight.
    func testHoldDayKeepsTheLastLoad() {
        let history = [session(dayOffset: -3, reps: 8, load: 50)]
        let engine = ProgressionEngine.today(sessions: history, asOf: day0, calendar: calendar)
        let draft = SessionPrototypePlan.make(sessions: history, phase: .cHeavySlowResistance, asOf: day0, calendar: calendar)
        XCTAssertEqual(draft.stanceLabel, "Hold the load")
        XCTAssertNil(engine.suggestedChangeLoadLbs)
        XCTAssertFalse(engine.cardReason.contains("Try"))
        XCTAssertEqual(draft.target.loadLbs, 50)
        XCTAssertTrue(draft.perSetTargetLine.contains("50 lb"), draft.perSetTargetLine)
        XCTAssertTrue(draft.sets.allSatisfy { $0.loadLbs == 50 })
        XCTAssertEqual(SessionPrototypePlan.loadDelta(draft.sets[1].loadLbs, target: draft.target.loadLbs), "Target")
    }

    func testIncreaseWithNoLoggedLoadNamesNoWeight() {
        let noLoad = LoadPrescription(workingSets: 3, reps: 8, loadLbs: nil)
        XCTAssertNil(ProgressionEngine.increased(noLoad).loadLbs)
        XCTAssertEqual(ProgressionEngine.increased(LoadPrescription(workingSets: 3, reps: 8, loadLbs: 50)).loadLbs, 55)
        XCTAssertEqual(SessionPrototypePlan.loadStep, ProgressionEngine.loadIncrementLbs, "One increment for the engine and the ruler")
    }

    func testSetRulersOpenAtTheTargetAndNextKeepsTheShownValues() {
        var draft = SessionPrototypePlan.make(
            sessions: [session(dayOffset: -3, reps: 8, load: 45)],
            phase: .aFlareDeLoad,
            asOf: day0,
            calendar: calendar
        )
        XCTAssertTrue(draft.sets.allSatisfy { $0.matchesTarget(draft.target) })
        XCTAssertEqual(SessionPrototypePlan.loadDelta(draft.sets[0].loadLbs, target: draft.target.loadLbs), "Target")
        // Off target: the delta label shows. The shown values are the values that save.
        draft.sets[0].loadLbs = 50
        XCTAssertEqual(SessionPrototypePlan.loadDelta(draft.sets[0].loadLbs, target: draft.target.loadLbs), "+5 lb")
        draft.painDuring = 1
        let work = SessionPrototypePlan.setsForSave(draft).filter { !$0.isWarmup }
        XCTAssertEqual(work.first?.loadLbs, 50)
        XCTAssertEqual(draft.phase, .aFlareDeLoad)
    }

    func testWarmupAndPainUseTheSessionSaveShape() throws {
        var draft = SessionPrototypePlan.make(
            sessions: [session(dayOffset: -3, reps: 8, load: 45)],
            phase: .cHeavySlowResistance,
            asOf: day0,
            calendar: calendar
        )
        // Next on each warm-up node includes the warm-up. The nodes are prefilled with the plan.
        draft.includeWarmup = true
        draft.painDuring = 2
        let saved = SessionPrototypePlan.setsForSave(draft)
        let warmup = saved.filter(\.isWarmup)
        let work = saved.filter { !$0.isWarmup }
        // No past warm-up, so the template from today's load is used.
        XCTAssertEqual(draft.warmup.source, .template)
        let working = try XCTUnwrap(draft.target.loadLbs)
        XCTAssertEqual(warmup.count, 3)
        XCTAssertEqual(warmup[0].holdSeconds, 30)
        XCTAssertEqual(warmup[0].reps, 1)
        XCTAssertNil(warmup[0].loadLbs)
        XCTAssertEqual(warmup[1].reps, 3)
        XCTAssertEqual(warmup[1].loadLbs, WarmupPlan.roundLoad(working * 0.5, step: 5))
        XCTAssertEqual(warmup[2].reps, 2)
        XCTAssertEqual(warmup[2].loadLbs, WarmupPlan.roundLoad(working * 0.75, step: 5))
        XCTAssertTrue(warmup.allSatisfy { $0.painDuring == nil })
        XCTAssertEqual(work.count, 6)
        XCTAssertTrue(work.allSatisfy { $0.painDuring == 2 })
        XCTAssertTrue(draft.whatIDid().contains("Seated leg extension"))
        XCTAssertTrue(draft.whatIDid().contains("Warm-up"))
    }

    func testGuidedStepsCoverTheQuestions() {
        let prompts = SessionPrototypePlan.guidedPrompts(warmupCount: 3, setCount: 3)
        XCTAssertEqual(prompts, [
            .exercise, .warmup(0), .warmup(1), .warmup(2), .set(0), .set(1), .set(2), .pain, .notes, .review
        ])
        let draft = SessionPrototypePlan.make(sessions: [], phase: .cHeavySlowResistance, asOf: day0, calendar: calendar)
        XCTAssertEqual(draft.prompts.filter { if case .warmup = $0 { return true } else { return false } }.count, 3,
                       "Each template step is one warm-up node")
        XCTAssertEqual(GuidedPrompt.set(0).accessibilityIdentifier, "prototype-guided-set-1")
        XCTAssertEqual(GuidedPrompt.warmup(1).accessibilityIdentifier, "prototype-guided-warmup-step-2")
        XCTAssertEqual(SessionPrototypeAccessibility.screen, "guided-session-screen")
        XCTAssertEqual(SessionPrototypeAccessibility.saveDraft, "guided-save-draft")
        XCTAssertEqual(SessionPrototypeAccessibility.painChip(2), "prototype-pain-chip-2")
    }

    func testRulerFollowsTheFingerAndLimitsTheFlick() {
        // Drag 3 ticks to the left: up 3 values. Stays inside the ruler.
        XCTAssertEqual(SessionPrototypePlan.rulerPosition(start: 9, dragPoints: -42, tickWidth: 14, count: 61), 12)
        XCTAssertEqual(SessionPrototypePlan.rulerPosition(start: 9, dragPoints: 21, tickWidth: 14, count: 61), 7.5)
        XCTAssertEqual(SessionPrototypePlan.rulerPosition(start: 1, dragPoints: 500, tickWidth: 14, count: 61), 0)
        XCTAssertEqual(SessionPrototypePlan.rulerPosition(start: 59, dragPoints: -500, tickWidth: 14, count: 61), 60)
        // A slow release adds nothing. A short flick adds 1 or 2. A hard flick adds 2, no more.
        XCTAssertEqual(SessionPrototypePlan.rulerFlickSteps(momentumPoints: -10, tickWidth: 14), 0)
        XCTAssertEqual(SessionPrototypePlan.rulerFlickSteps(momentumPoints: -60, tickWidth: 14), 1)
        XCTAssertEqual(SessionPrototypePlan.rulerFlickSteps(momentumPoints: -100, tickWidth: 14), 2)
        XCTAssertEqual(SessionPrototypePlan.rulerFlickSteps(momentumPoints: -2_000, tickWidth: 14), 2)
        XCTAssertEqual(SessionPrototypePlan.rulerFlickSteps(momentumPoints: 2_000, tickWidth: 14), -2)
        XCTAssertEqual(SessionPrototypePlan.rulerFinalIndex(position: 9.4, momentumPoints: -2_000, tickWidth: 14, count: 61), 11)
        XCTAssertEqual(SessionPrototypePlan.rulerFinalIndex(position: 9.6, momentumPoints: 0, tickWidth: 14, count: 61), 10)
        XCTAssertEqual(SessionPrototypePlan.rulerFinalIndex(position: 60, momentumPoints: -2_000, tickWidth: 14, count: 61), 60)
        XCTAssertEqual(SessionPrototypePlan.rulerFinalIndex(position: 0, momentumPoints: 2_000, tickWidth: 14, count: 61), 0)
        XCTAssertEqual(SessionPrototypeAccessibility.setRuler(set: 0, field: "load"), "prototype-guided-set-1-load-ruler")
    }

    func testLoadStepsAndDeltaLabels() {
        XCTAssertEqual(SessionPrototypePlan.load(45, ticks: 1), 50)
        XCTAssertEqual(SessionPrototypePlan.load(nil, ticks: 2), 10)
        XCTAssertNil(SessionPrototypePlan.load(5, ticks: -1))
        XCTAssertNil(SessionPrototypePlan.load(nil, ticks: -1))
        XCTAssertEqual(SessionPrototypePlan.load(295, ticks: 4), SessionPrototypePlan.maxLoad)
        XCTAssertEqual(SessionPrototypePlan.loadIndex(45), 9)
        XCTAssertEqual(SessionPrototypePlan.loadIndex(nil), 0)
        XCTAssertEqual(SessionPrototypePlan.load(atIndex: 9), 45)
        XCTAssertNil(SessionPrototypePlan.load(atIndex: 0))
        XCTAssertEqual(SessionPrototypePlan.loadIndexCount, 61)
        XCTAssertEqual(SessionPrototypePlan.repsDelta(8, target: 8), "Target")
        XCTAssertEqual(SessionPrototypePlan.repsDelta(10, target: 8), "+2 reps")
        XCTAssertEqual(SessionPrototypePlan.repsDelta(7, target: 8), "\u{2212}1 rep")
        XCTAssertEqual(SessionPrototypePlan.loadDelta(50, target: 45), "+5 lb")
        XCTAssertEqual(SessionPrototypePlan.loadDelta(35, target: 45), "\u{2212}10 lb")
        XCTAssertEqual(SessionPrototypePlan.loadDelta(nil, target: nil), "Target")
    }

    func testSetsOpenAtTheRecommendation() {
        let draft = SessionPrototypePlan.make(
            sessions: [session(dayOffset: -3, reps: 8, load: 45)],
            phase: .cHeavySlowResistance,
            asOf: day0,
            calendar: calendar
        )
        XCTAssertFalse(draft.sets.isEmpty)
        XCTAssertTrue(draft.sets.allSatisfy { $0.matchesTarget(draft.target) })
    }

    private func session(dayOffset: Int, reps: Int, load: Double) -> TrainingSessionSnapshot {
        let date = calendar.date(byAdding: .day, value: dayOffset, to: day0)!
        let rows = SessionPrefill.workSets(
            from: LoadPrescription(workingSets: 3, reps: reps, loadLbs: load),
            laterality: .bilateral
        )
        return TrainingSessionSnapshot(
            date: date,
            createdAt: date.addingTimeInterval(60),
            sessionType: .hsrStrength,
            response24h: .same,
            decision: .stay,
            resolvedAt: date.addingTimeInterval(86_400),
            snoozedUntil: nil,
            phase: .cHeavySlowResistance,
            painDuring: 2,
            painAfter: 2,
            whatIDid: "Seated leg extension · 3×\(reps) @ \(LoadCopy.labeled(load))",
            resistanceSets: rows
        )
    }
    func testNextGoesToTheNextStepOrBackToTheFirstUnfinishedStep() {
        // Normal: one step forward.
        XCTAssertEqual(SessionPrototypePlan.nextIndex(current: 2, furthest: 2, count: 10), 3)
        // Reopened warm-up 1 (index 1) while set 2 (index 5) is unfinished: Next goes to set 2.
        XCTAssertEqual(SessionPrototypePlan.nextIndex(current: 1, furthest: 5, count: 10), 5)
        // After Back from set 2 to set 1: Next goes to set 2.
        XCTAssertEqual(SessionPrototypePlan.nextIndex(current: 4, furthest: 5, count: 10), 5)
        XCTAssertEqual(SessionPrototypePlan.nextIndex(current: 9, furthest: 9, count: 10), 9)
    }

    func testStepperNodesFillAsEachStepIsDone() {
        XCTAssertTrue(SessionPrototypePlan.isStepDone(1, furthest: 3))
        XCTAssertTrue(SessionPrototypePlan.isStepDone(2, furthest: 3))
        XCTAssertFalse(SessionPrototypePlan.isStepDone(3, furthest: 3), "The first unfinished step is not done")
        XCTAssertFalse(SessionPrototypePlan.isStepDone(4, furthest: 3))
        XCTAssertFalse(SessionPrototypePlan.isStepDone(-1, furthest: 3))
    }

    func testNodeTapOpensOnlyDoneSteps() {
        XCTAssertEqual(SessionPrototypePlan.nodeTarget(tapped: 0, current: 3, furthest: 3), 0)
        XCTAssertEqual(SessionPrototypePlan.nodeTarget(tapped: 2, current: 3, furthest: 3), 2)
        XCTAssertNil(SessionPrototypePlan.nodeTarget(tapped: 3, current: 3, furthest: 3), "The current node does not open")
        XCTAssertNil(SessionPrototypePlan.nodeTarget(tapped: 4, current: 3, furthest: 3), "A later node does not open")
        XCTAssertNil(SessionPrototypePlan.nodeTarget(tapped: -1, current: 3, furthest: 3))
        // From a reopened step, a later done node opens. The first unfinished node does not: Next goes there.
        XCTAssertEqual(SessionPrototypePlan.nodeTarget(tapped: 4, current: 1, furthest: 5), 4)
        XCTAssertNil(SessionPrototypePlan.nodeTarget(tapped: 5, current: 1, furthest: 5))
    }

    func testSwipeBackStopsAtStepOne() {
        XCTAssertEqual(SessionPrototypePlan.swipeTarget(.back, current: 3, furthest: 5, count: 10), 2)
        XCTAssertEqual(SessionPrototypePlan.swipeTarget(.back, current: 1, furthest: 5, count: 10), 0)
        XCTAssertNil(SessionPrototypePlan.swipeTarget(.back, current: 0, furthest: 5, count: 10), "A swipe on step 1 does not close")
    }

    func testSwipeForwardStopsAtTheFurthestStep() {
        // Behind the furthest step: one step forward each swipe, up to the furthest step.
        XCTAssertEqual(SessionPrototypePlan.swipeTarget(.forward, current: 2, furthest: 5, count: 10), 3)
        XCTAssertEqual(SessionPrototypePlan.swipeTarget(.forward, current: 4, furthest: 5, count: 10), 5)
        // At the furthest step: no skip ahead. Only Next records and goes on.
        XCTAssertNil(SessionPrototypePlan.swipeTarget(.forward, current: 5, furthest: 5, count: 10))
        // The furthest step cannot be past the last step.
        XCTAssertNil(SessionPrototypePlan.swipeTarget(.forward, current: 9, furthest: 12, count: 10))
        XCTAssertNil(SessionPrototypePlan.swipeTarget(.forward, current: 0, furthest: 0, count: 0))
    }

    func testBackThenForwardReturnsToTheFurthestStep() {
        var current = 6
        let furthest = 6
        for _ in 0..<3 { current = SessionPrototypePlan.swipeTarget(.back, current: current, furthest: furthest, count: 10)! }
        XCTAssertEqual(current, 3)
        while let next = SessionPrototypePlan.swipeTarget(.forward, current: current, furthest: furthest, count: 10) {
            current = next
        }
        XCTAssertEqual(current, furthest, "Forward swipes stop at the furthest step")
        // From an earlier step, Next also goes to the furthest step.
        XCTAssertEqual(SessionPrototypePlan.nextIndex(current: 3, furthest: furthest, count: 10), furthest)
    }

    func testStepSwipeDirectionAndRulerEdges() {
        // Not a step swipe: too short or mostly vertical.
        XCTAssertNil(SessionPrototypePlan.stepSwipe(startX: 200, width: 390, dx: -30, dy: 0, hasRulers: false))
        XCTAssertNil(SessionPrototypePlan.stepSwipe(startX: 200, width: 390, dx: -60, dy: 90, hasRulers: false))
        // A step without rulers: a swipe from any point.
        XCTAssertEqual(SessionPrototypePlan.stepSwipe(startX: 200, width: 390, dx: -60, dy: 5, hasRulers: false), .forward)
        XCTAssertEqual(SessionPrototypePlan.stepSwipe(startX: 200, width: 390, dx: 60, dy: 5, hasRulers: false), .back)
        // A step with rulers: a drag that starts on the ruler area only moves the ruler.
        XCTAssertNil(SessionPrototypePlan.stepSwipe(startX: 200, width: 390, dx: -60, dy: 0, hasRulers: true))
        XCTAssertNil(SessionPrototypePlan.stepSwipe(startX: 40, width: 390, dx: 60, dy: 0, hasRulers: true))
        // A swipe from a screen edge changes the step.
        XCTAssertEqual(SessionPrototypePlan.stepSwipe(startX: 10, width: 390, dx: 80, dy: 4, hasRulers: true), .back)
        XCTAssertEqual(SessionPrototypePlan.stepSwipe(startX: 380, width: 390, dx: -80, dy: 4, hasRulers: true), .forward)
        // The rulers start 20 pt + the card padding from the edge, so they are outside the edge area.
        XCTAssertLessThan(SessionPrototypePlan.stepSwipeEdge, 34)
    }

    func testDeleteGoesToTheFirstUnfinishedStep() {
        // Delete warm-up 1 (index 1) while set 1 (index 4) is unfinished: set 1 is now index 3.
        let after = SessionPrototypePlan.afterDelete(deleted: 1, furthest: 4, count: 9)
        XCTAssertEqual(after.current, 3)
        XCTAssertEqual(after.furthest, 3)
        // Delete the current extra step (at the first unfinished step): the next step moves into its place.
        let extra = SessionPrototypePlan.afterDelete(deleted: 4, furthest: 4, count: 9)
        XCTAssertEqual(extra.current, 4)
        XCTAssertEqual(extra.furthest, 4)
    }
}
