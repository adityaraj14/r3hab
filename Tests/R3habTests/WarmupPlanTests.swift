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
        XCTAssertTrue(plan.steps.isEmpty, "Finished list starts empty")
        XCTAssertEqual(plan.planned.count, 2)
        XCTAssertEqual(plan.planIndex, 0)
        XCTAssertEqual(plan.planned[0].kind, .hold)
        XCTAssertEqual(plan.planned[0].seconds, 40)
        XCTAssertEqual(plan.planned[1].kind, .reps)
        XCTAssertEqual(plan.planned[1].reps, 4)
        XCTAssertEqual(plan.planned[1].loadLbs, 30)
        XCTAssertTrue(plan.planned.allSatisfy(\.fromLastSession))
        let composer = plan.composerForPlan()
        XCTAssertEqual(composer.kind, .hold)
        XCTAssertEqual(composer.seconds, 40)
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
        XCTAssertTrue(plan.steps.isEmpty)
        XCTAssertEqual(plan.planned.map(\.reps), [3])
        XCTAssertEqual(plan.planned.first?.loadLbs, 20)
    }

    func testPrefillUsesTemplateWhenThereIsNoPastWarmup() {
        let plan = WarmupPlan.prefill(sessions: [session(daysAgo: 2, warmup: [])], workingLoad: 60, loadStep: 5)
        XCTAssertEqual(plan.source, .template)
        XCTAssertTrue(plan.steps.isEmpty)
        XCTAssertEqual(plan.planned.map(\.loadLbs), [nil, 30, 45])
        XCTAssertFalse(plan.planned.contains(where: \.fromLastSession))
        let composer = plan.composerForPlan()
        XCTAssertEqual(composer.kind, .hold)
        XCTAssertEqual(composer.seconds, 30)
    }

    func testPrefillWithNoHistoryAndNoLoadIsBlank() {
        let plan = WarmupPlan.prefill(sessions: [], workingLoad: nil, loadStep: 5)
        XCTAssertEqual(plan.source, .blank)
        XCTAssertTrue(plan.steps.isEmpty)
        XCTAssertTrue(plan.planned.isEmpty)
        let composer = plan.composerForPlan()
        XCTAssertEqual(composer.kind, .hold)
        XCTAssertEqual(composer.seconds, 30)
        XCTAssertEqual(composer.reps, 3)
    }

    func testComposerDefaultsHoldAt30AndRepsAt3() {
        let empty = WarmupComposer.empty
        XCTAssertEqual(empty.kind, .hold)
        XCTAssertEqual(empty.seconds, 30)
        XCTAssertEqual(empty.reps, 3)
        XCTAssertNil(empty.loadLbs)

        var composer = WarmupComposer.empty
        composer.selectKind(.reps)
        XCTAssertEqual(composer.kind, .reps)
        XCTAssertEqual(composer.reps, 3)
        XCTAssertEqual(composer.seconds, 30)

        composer.selectKind(.hold)
        XCTAssertEqual(composer.seconds, 30)

        let step = WarmupComposer(kind: .hold, seconds: 30, loadLbs: 10).makeStep()
        XCTAssertEqual(step.kind, .hold)
        XCTAssertEqual(step.seconds, 30)
        XCTAssertEqual(step.loadLbs, 10)
    }

    func testHoldRulerMapsThirtySeconds() {
        XCTAssertEqual(WarmupPlan.holdSeconds(atIndex: WarmupPlan.holdSecondsIndex(30)), 30)
        XCTAssertEqual(WarmupPlan.holdSeconds(atIndex: 0), 5)
        XCTAssertEqual(WarmupPlan.holdSeconds(atIndex: WarmupPlan.holdSecondsIndexCount - 1), 120)
    }

    func testAddCommittedAppendsAndCapsAtMax() {
        var plan = WarmupPlan(steps: [], source: .blank)
        XCTAssertTrue(plan.addCommitted(.hold(seconds: 30, loadLbs: nil)))
        XCTAssertEqual(plan.steps.count, 1)
        XCTAssertEqual(plan.steps[0].seconds, 30)
        for _ in 0..<WarmupPlan.maxSteps {
            _ = plan.addCommitted(.reps(3, loadLbs: 20))
        }
        XCTAssertEqual(plan.steps.count, WarmupPlan.maxSteps)
        XCTAssertFalse(plan.addCommitted(.hold()))
    }

    func testAddFromComposerAdvancesThroughPlannedStepsThenRepeatsLast() {
        var plan = WarmupPlan(
            steps: [],
            planned: [
                .hold(seconds: 40, loadLbs: nil),
                .reps(3, loadLbs: 30),
                .reps(2, loadLbs: 45)
            ],
            planIndex: 0,
            source: .template
        )
        XCTAssertEqual(plan.composerForPlan().kind, .hold)
        XCTAssertEqual(plan.composerForPlan().seconds, 40)

        XCTAssertTrue(plan.addFromComposer(plan.composerForPlan().makeStep()))
        XCTAssertEqual(plan.steps.count, 1)
        XCTAssertEqual(plan.planIndex, 1)
        XCTAssertEqual(plan.composerForPlan().kind, .reps)
        XCTAssertEqual(plan.composerForPlan().reps, 3)
        XCTAssertEqual(plan.composerForPlan().loadLbs, 30)

        XCTAssertTrue(plan.addFromComposer(plan.composerForPlan().makeStep()))
        XCTAssertEqual(plan.planIndex, 2)
        XCTAssertEqual(plan.composerForPlan().reps, 2)
        XCTAssertEqual(plan.composerForPlan().loadLbs, 45)

        XCTAssertTrue(plan.addFromComposer(plan.composerForPlan().makeStep()))
        XCTAssertEqual(plan.planIndex, 3)
        // Past the plan: repeat the last planned step.
        XCTAssertEqual(plan.composerForPlan().reps, 2)
        XCTAssertEqual(plan.composerForPlan().loadLbs, 45)
    }

    func testPrefillWithNoLoadStillPrefersTheLastWarmup() {
        let past = session(daysAgo: 2, warmup: [
            ResistanceSet(reps: 3, loadLbs: 15, holdSeconds: nil, isWarmup: true)
        ])
        let plan = WarmupPlan.prefill(sessions: [past], workingLoad: nil, loadStep: 5)
        XCTAssertEqual(plan.source, .lastSession)
        XCTAssertTrue(plan.steps.isEmpty)
        XCTAssertEqual(plan.planned.first?.loadLbs, 15)
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
        plan.addStep()
        XCTAssertEqual(plan.steps.map(\.kind), [.hold])
        plan.update(id: plan.steps[0].id) { $0.kind = .reps; $0.reps = 4; $0.loadLbs = 20 }
        plan.addStep()
        XCTAssertEqual(plan.steps.count, 2)
        XCTAssertEqual(plan.steps[1].reps, 4)
        XCTAssertEqual(plan.steps[1].loadLbs, 20)
        XCTAssertNotEqual(plan.steps[0].id, plan.steps[1].id)
        for _ in 0..<10 { plan.addStep() }
        XCTAssertEqual(plan.steps.count, WarmupPlan.maxSteps)
        plan.removeStep(id: plan.steps[0].id)
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
