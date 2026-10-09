import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class WarmupPlanTests: XCTestCase {
    private let day0 = Date(timeIntervalSince1970: 1_777_766_400)

    // MARK: Template math

    func testTemplateIsHoldThenHalfThenThreeQuarters() {
        let steps = WarmupPlan.template(workingLoad: 60, loadStep: 5)
        XCTAssertEqual(steps.map(\.kind), [.hold, .reps, .reps])
        XCTAssertEqual(steps[0].seconds, 30)
        XCTAssertNil(steps[0].loadLbs)
        XCTAssertEqual(steps[1].reps, 3)
        XCTAssertEqual(steps[1].loadLbs, 30)
        XCTAssertEqual(steps[2].reps, 2)
        XCTAssertEqual(steps[2].loadLbs, 45)
    }

    func testTemplateRoundsToTheMachineStep() {
        // 45 × 0.5 = 22.5 -> 25. 45 × 0.75 = 33.75 -> 35.
        let steps = WarmupPlan.template(workingLoad: 45, loadStep: 5)
        XCTAssertEqual(steps[1].loadLbs, 25)
        XCTAssertEqual(steps[2].loadLbs, 35)
        // 70 × 0.5 = 35. 70 × 0.75 = 52.5 -> 55.
        let heavier = WarmupPlan.template(workingLoad: 70, loadStep: 5)
        XCTAssertEqual(heavier[1].loadLbs, 35)
        XCTAssertEqual(heavier[2].loadLbs, 55)
        XCTAssertEqual(WarmupPlan.roundLoad(12.4, step: 5), 10)
        XCTAssertEqual(WarmupPlan.roundLoad(12.5, step: 5), 15)
        XCTAssertEqual(WarmupPlan.roundLoad(12.4, step: 0), 12.4)
    }

    func testTemplateNeverGoesBelowOneStepOrAboveWorkingLoad() {
        let light = WarmupPlan.template(workingLoad: 5, loadStep: 5)
        XCTAssertEqual(light[1].loadLbs, 5)
        XCTAssertEqual(light[2].loadLbs, 5)
        let tiny = WarmupPlan.template(workingLoad: 2, loadStep: 5)
        XCTAssertEqual(tiny[1].loadLbs, 2)
        XCTAssertEqual(tiny[2].loadLbs, 2)
    }

    func testTemplateWithoutWorkingLoadHasNoLoads() {
        for load in [nil, 0.0] as [Double?] {
            let steps = WarmupPlan.template(workingLoad: load, loadStep: 5)
            XCTAssertEqual(steps.map(\.kind), [.hold, .reps, .reps])
            XCTAssertTrue(steps.allSatisfy { $0.loadLbs == nil })
        }
    }

    // MARK: Prefill rules

    func testPrefillUsesTheLastSavedWarmup() {
        let older = session(daysAgo: 6, warmup: [
            ResistanceSet(reps: 5, loadLbs: 10, holdSeconds: nil, isWarmup: true)
        ])
        let newer = session(daysAgo: 2, warmup: [
            ResistanceSet(reps: 1, loadLbs: nil, holdSeconds: 40, isWarmup: true),
            ResistanceSet(reps: 4, loadLbs: 30, holdSeconds: nil, isWarmup: true)
        ])
        let plan = WarmupPlan.prefill(sessions: [older, newer], workingLoad: 60, loadStep: 5)
        XCTAssertEqual(plan.source, .lastSession)
        XCTAssertEqual(plan.planned.count, 2)
        XCTAssertEqual(plan.planned[0].kind, .hold)
        XCTAssertEqual(plan.planned[0].seconds, 40)
        XCTAssertEqual(plan.planned[1].kind, .reps)
        XCTAssertEqual(plan.planned[1].reps, 4)
        XCTAssertEqual(plan.planned[1].loadLbs, 30)
        XCTAssertTrue(plan.planned.allSatisfy(\.fromLastSession))
        // Each planned step is one node on the stepper, prefilled.
        XCTAssertEqual(plan.steps, plan.planned)
    }

    func testPrefillSkipsSessionsWithoutWarmupAndDrafts() {
        let withWarmup = session(daysAgo: 7, warmup: [
            ResistanceSet(reps: 3, loadLbs: 20, holdSeconds: nil, isWarmup: true)
        ])
        let noWarmup = session(daysAgo: 3, warmup: [])
        var draft = session(daysAgo: 1, warmup: [
            ResistanceSet(reps: 9, loadLbs: 90, holdSeconds: nil, isWarmup: true)
        ])
        draft.isDraft = true
        let plan = WarmupPlan.prefill(sessions: [noWarmup, draft, withWarmup], workingLoad: 60, loadStep: 5)
        XCTAssertEqual(plan.source, .lastSession)
        XCTAssertEqual(plan.steps.map(\.reps), [3])
        XCTAssertEqual(plan.steps.first?.loadLbs, 20)
    }

    func testPrefillUsesTemplateWhenThereIsNoPastWarmup() {
        let plan = WarmupPlan.prefill(sessions: [session(daysAgo: 2, warmup: [])], workingLoad: 60, loadStep: 5)
        XCTAssertEqual(plan.source, .template)
        XCTAssertEqual(plan.steps.map(\.kind), [.hold, .reps, .reps])
        XCTAssertEqual(plan.steps.map(\.loadLbs), [nil, 30, 45])
        XCTAssertFalse(plan.steps.contains(where: \.fromLastSession))
        XCTAssertEqual(plan.steps, plan.planned)
    }

    /// The bug in the footer shots: with no history and no working load, warm-up 2 was "Hold 30 s".
    /// The template order stays: hold, then 3 reps, then 2 reps, with no loads.
    func testPrefillWithNoHistoryAndNoLoadUsesTheTemplateOrder() {
        for load in [nil, 0.0] as [Double?] {
            let plan = WarmupPlan.prefill(sessions: [], workingLoad: load, loadStep: 5)
            XCTAssertEqual(plan.source, .blank)
            XCTAssertEqual(plan.steps.map(\.kind), [.hold, .reps, .reps])
            XCTAssertEqual(plan.steps.map(\.line), ["Hold 30 s", "3 reps", "2 reps"])
            XCTAssertTrue(plan.steps.allSatisfy { $0.loadLbs == nil })
            XCTAssertEqual(plan.steps, plan.planned)
        }
    }

    func testHoldRulerMapsThirtySeconds() {
        XCTAssertEqual(WarmupPlan.holdSeconds(atIndex: WarmupPlan.holdSecondsIndex(30)), 30)
        XCTAssertEqual(WarmupPlan.holdSeconds(atIndex: 0), 5)
        XCTAssertEqual(WarmupPlan.holdSeconds(atIndex: WarmupPlan.holdSecondsIndexCount - 1), 120)
    }

    func testPlusNodeAddsAnExtraStepWithoutATarget() {
        var plan = WarmupPlan.prefill(sessions: [], workingLoad: 60, loadStep: 5)
        XCTAssertNotNil(plan.target(at: 2))
        XCTAssertFalse(plan.isExtra(at: 2))
        XCTAssertTrue(plan.addStep())
        XCTAssertEqual(plan.steps.count, 4)
        // A copy of the last step.
        XCTAssertEqual(plan.steps[3].line, plan.steps[2].line)
        XCTAssertTrue(plan.isExtra(at: 3))
        XCTAssertNil(plan.target(at: 3))
        plan.removeExtraSteps()
        XCTAssertEqual(plan.steps.count, 3)
    }

    func testDeleteRemovesTheStepAndItsTarget() {
        var plan = WarmupPlan.prefill(sessions: [], workingLoad: 60, loadStep: 5)
        plan.removeStep(at: 1)
        XCTAssertEqual(plan.steps.map(\.loadLbs), [nil, 45])
        XCTAssertEqual(plan.planned.map(\.loadLbs), [nil, 45], "Later steps keep their own targets")
        plan.removeStep(at: 9)
        XCTAssertEqual(plan.steps.count, 2)
    }

    func testPrefillWithNoLoadStillPrefersTheLastWarmup() {
        let past = session(daysAgo: 2, warmup: [
            ResistanceSet(reps: 3, loadLbs: 15, holdSeconds: nil, isWarmup: true)
        ])
        let plan = WarmupPlan.prefill(sessions: [past], workingLoad: nil, loadStep: 5)
        XCTAssertEqual(plan.source, .lastSession)
        XCTAssertEqual(plan.steps.first?.loadLbs, 15)
    }

    // MARK: Old rows and save shape

    func testOldTwoHoldRowBecomesTwoHoldSteps() {
        let old = SessionPrefill.warmupSet(loadLbs: 45) // 2 × 30 s @ 45 lb
        let steps = WarmupPlan.steps(from: [old])
        XCTAssertEqual(steps.count, 2)
        XCTAssertTrue(steps.allSatisfy { $0.kind == .hold && $0.seconds == 30 && $0.loadLbs == 45 })
    }

    func testRightSideRowIsNotAnExtraStep() {
        let rows = SessionSummary.makePair(reps: 3, loadLbs: 20, holdSeconds: nil, isWarmup: true)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(WarmupPlan.steps(from: rows).count, 1)
    }

    func testStepsSaveAsWarmupRowsAndRoundTrip() {
        let plan = WarmupPlan(
            steps: [.hold(seconds: 35, loadLbs: nil), .reps(3, loadLbs: 25), .reps(2, loadLbs: 0)],
            source: .template
        )
        let rows = plan.resistanceSets()
        XCTAssertTrue(rows.allSatisfy(\.isWarmup))
        XCTAssertEqual(rows[0].reps, 1)
        XCTAssertEqual(rows[0].holdSeconds, 35)
        XCTAssertNil(rows[1].holdSeconds)
        XCTAssertEqual(rows[1].reps, 3)
        XCTAssertEqual(rows[1].loadLbs, 25)
        XCTAssertNil(rows[2].loadLbs, "Zero load saves as no load")
        XCTAssertNil(SessionSaveValidation.validate(painDuring: 2, painAfter: nil, whatIDid: "x", sets: rows))
        let back = WarmupPlan.steps(from: rows)
        XCTAssertEqual(back.map(\.kind), [.hold, .reps, .reps])
        XCTAssertEqual(back.map(\.line), ["Hold 35 s", "3 × 25 lb", "2 reps"])
    }

    // MARK: Edits

    func testEditsClearTheLastSessionMarkAndKeepValues() {
        var step = WarmupStep.hold(seconds: 30, loadLbs: nil)
        step.fromLastSession = true
        var plan = WarmupPlan(steps: [step], source: .lastSession)
        plan.update(id: step.id) { $0.kind = .reps }
        XCTAssertEqual(plan.steps[0].kind, .reps)
        XCTAssertEqual(plan.steps[0].seconds, 30)
        XCTAssertFalse(plan.steps[0].fromLastSession)
        plan.update(id: step.id) { $0.kind = .hold }
        XCTAssertEqual(plan.steps[0].line, "Hold 30 s")
    }

    func testAddAndRemoveSteps() {
        var plan = WarmupPlan(steps: [], source: .blank)
        XCTAssertTrue(plan.addStep())
        XCTAssertEqual(plan.steps.map(\.kind), [.hold])
        plan.update(id: plan.steps[0].id) { $0.kind = .reps; $0.reps = 4; $0.loadLbs = 20 }
        plan.addStep()
        XCTAssertEqual(plan.steps.count, 2)
        XCTAssertEqual(plan.steps[1].reps, 4)
        XCTAssertEqual(plan.steps[1].loadLbs, 20)
        XCTAssertNotEqual(plan.steps[0].id, plan.steps[1].id)
        for _ in 0..<10 { plan.addStep() }
        XCTAssertEqual(plan.steps.count, WarmupPlan.maxSteps)
        XCTAssertFalse(plan.addStep(), "The stepper is full")
        plan.removeStep(at: 0)
        XCTAssertEqual(plan.steps.count, WarmupPlan.maxSteps - 1)
    }

    private func session(daysAgo: Int, warmup: [ResistanceSet]) -> TrainingSessionSnapshot {
        let date = day0.addingTimeInterval(Double(-daysAgo) * 86_400)
        let work = SessionPrefill.workSets(
            from: LoadPrescription(workingSets: 3, reps: 8, loadLbs: 60),
            laterality: .bilateral
        )
        return TrainingSessionSnapshot(
            date: date,
            createdAt: date.addingTimeInterval(60),
            sessionType: .hsrStrength,
            response24h: .same,
            decision: .stay,
            resolvedAt: nil,
            snoozedUntil: nil,
            phase: .cHeavySlowResistance,
            painDuring: 2,
            whatIDid: "Seated leg extension",
            resistanceSets: warmup + work
        )
    }
}
