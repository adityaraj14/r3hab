import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

/// Save draft on each guided step, resume, older drafts, and background autosave.
final class GuidedCheckpointTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var day0: Date {
        calendar.startOfDay(for: Date(timeIntervalSince1970: 1_777_766_400))
    }

    private func plan(history: [TrainingSessionSnapshot]? = nil) -> SessionPrototypeDraft {
        SessionPrototypePlan.make(
            sessions: history ?? [prior(load: 45)],
            phase: .cHeavySlowResistance,
            asOf: day0,
            calendar: calendar
        )
    }

    /// A draft with values on each kind of step: warm-up edit, two changed sets, pain, notes.
    private func filled() -> SessionPrototypeDraft {
        var draft = plan()
        // Prefill feeds the composer; commit finished sets like the Add button.
        let planned = draft.warmup.planned
        if planned.count >= 2 {
            _ = draft.warmup.addFromComposer(planned[0])
            var second = planned[1]
            second.reps = 5
            _ = draft.warmup.addFromComposer(second)
        } else {
            _ = draft.warmup.addFromComposer(.hold())
            _ = draft.warmup.addFromComposer(.reps(5, loadLbs: 20))
        }
        draft.includeWarmup = true
        draft.sets[0].reps = 10
        draft.sets[0].loadLbs = 50
        draft.sets[1].loadLbs = 40
        draft.painDuring = 3
        draft.notes = "Felt fine"
        return draft
    }

    // MARK: Each step

    func testCheckpointRoundTripsOnEveryStep() {
        let source = filled()
        let prompts = SessionPrototypePlan.guidedPrompts(setCount: source.sets.count)
        for (index, prompt) in prompts.enumerated() {
            var draft = source
            // Before the warm-up choice, the user has not said "Warm-up done".
            if index <= GuidedCheckpointing.warmupIndex { draft.includeWarmup = false }
            // Before the pain step, there is no pain value yet.
            let painIndex = prompts.firstIndex(of: .pain)!
            if index < painIndex { draft.painDuring = nil }
            // Notes come after pain.
            if index <= painIndex { draft.notes = "" }

            let saved = GuidedCheckpointing.checkpoint(draft, stepIndex: index)
            XCTAssertEqual(saved.stepIndex, index, "\(prompt)")
            XCTAssertEqual(saved.painDuring, draft.painDuring ?? PainScore.notLogged, "\(prompt)")

            let restored = GuidedCheckpointing.restore(saved, onto: plan())
            XCTAssertEqual(restored.stepIndex, index, "Resume opens on \(prompt)")
            XCTAssertEqual(restored.draft.sets.map(\.reps), draft.sets.map(\.reps), "\(prompt)")
            XCTAssertEqual(restored.draft.sets.map(\.loadLbs), draft.sets.map(\.loadLbs), "\(prompt)")
            XCTAssertEqual(restored.draft.painDuring, draft.painDuring, "\(prompt)")
            XCTAssertEqual(restored.draft.notes, draft.notes, "\(prompt)")
            XCTAssertEqual(restored.draft.includeWarmup, draft.includeWarmup, "\(prompt)")
            XCTAssertEqual(
                restored.draft.warmup.resistanceSets().map(\.reps),
                draft.warmup.resistanceSets().map(\.reps),
                "Warm-up edits stay on \(prompt)"
            )
            XCTAssertEqual(restored.draft.sessionType, .hsrStrength)
        }
    }

    func testSkippedWarmupStaysSkipped() {
        var draft = plan()
        draft.includeWarmup = false
        let saved = GuidedCheckpointing.checkpoint(draft, stepIndex: 3)
        XCTAssertFalse(saved.resistanceSets.contains(where: \.isWarmup))
        let restored = GuidedCheckpointing.restore(saved, onto: plan())
        XCTAssertFalse(restored.draft.includeWarmup)
        XCTAssertEqual(restored.stepIndex, 3)
        // The planned warm-up is still there if the user goes back.
        XCTAssertEqual(restored.draft.warmup.planned.map(\.loadLbs), plan().warmup.planned.map(\.loadLbs))
        XCTAssertEqual(restored.draft.warmup.source, plan().warmup.source)
    }

    func testUnchangedWarmupKeepsItsSource() {
        var history = [prior(load: 45)]
        history[0].resistanceSets.insert(
            ResistanceSet(reps: 4, loadLbs: 20, holdSeconds: nil, isWarmup: true),
            at: 0
        )
        let base = plan(history: history)
        XCTAssertEqual(base.warmup.source, .lastSession)
        XCTAssertTrue(base.warmup.steps.isEmpty)
        XCTAssertEqual(base.warmup.planned.map(\.reps), [4])
        var draft = base
        // Add the planned set so Warm-up done can be true (finished list was empty).
        XCTAssertTrue(draft.warmup.addFromComposer(draft.warmup.composerForPlan().makeStep()))
        draft.includeWarmup = true
        let saved = GuidedCheckpointing.checkpoint(draft, stepIndex: 2)
        let restored = GuidedCheckpointing.restore(saved, onto: base)
        XCTAssertEqual(restored.draft.warmup.source, .lastSession)
        XCTAssertEqual(restored.draft.warmup.planned.map(\.reps), base.warmup.planned.map(\.reps))
        XCTAssertEqual(restored.draft.warmup.steps.map(\.reps), [4])
        XCTAssertTrue(restored.draft.includeWarmup)
    }

    func testStepIndexIsClamped() {
        var saved = GuidedCheckpointing.checkpoint(filled(), stepIndex: 99)
        let last = SessionPrototypePlan.guidedPrompts(setCount: 3).count - 1
        XCTAssertEqual(saved.stepIndex, last)
        saved.stepIndex = -4
        XCTAssertEqual(GuidedCheckpointing.restore(saved, onto: plan()).stepIndex, 0)
    }

    func testStepsAfterPainNeedAPainValue() {
        var draft = filled()
        draft.painDuring = nil
        let review = SessionPrototypePlan.guidedPrompts(setCount: 3).count - 1
        let saved = GuidedCheckpointing.checkpoint(draft, stepIndex: review)
        let restored = GuidedCheckpointing.restore(saved, onto: plan())
        let painIndex = SessionPrototypePlan.guidedPrompts(setCount: 3).firstIndex(of: .pain)!
        XCTAssertEqual(restored.stepIndex, painIndex)
    }

    // MARK: Older drafts (no step index)

    func testOldDraftWithoutPainOpensAtStepOne() {
        let old = GuidedCheckpoint(
            phase: .cHeavySlowResistance,
            sessionType: .hsrStrength,
            whatIDid: "",
            painDuring: PainScore.notLogged,
            notes: "From the old form",
            resistanceSets: SessionPrefill.workSets(
                from: LoadPrescription(workingSets: 2, reps: 9, loadLbs: 35),
                laterality: .bilateral
            ),
            stepIndex: nil
        )
        let restored = GuidedCheckpointing.restore(old, onto: plan())
        XCTAssertEqual(restored.stepIndex, 0)
        XCTAssertEqual(restored.draft.sets.count, 2)
        XCTAssertTrue(restored.draft.sets.allSatisfy { $0.reps == 9 && $0.loadLbs == 35 })
        XCTAssertEqual(restored.draft.notes, "From the old form")
        XCTAssertNil(restored.draft.painDuring)
    }

    func testOldDraftWithPainAndWarmupOpensAtReview() {
        var rows = [ResistanceSet(reps: 1, loadLbs: nil, holdSeconds: 30, isWarmup: true)]
        rows += SessionPrefill.workSets(
            from: LoadPrescription(workingSets: 3, reps: 8, loadLbs: 45),
            laterality: .bilateral
        )
        let old = GuidedCheckpoint(
            phase: .cHeavySlowResistance,
            sessionType: .hsrStrength,
            whatIDid: "",
            painDuring: 2,
            notes: "",
            resistanceSets: rows,
            stepIndex: nil
        )
        let restored = GuidedCheckpointing.restore(old, onto: plan())
        let prompts = SessionPrototypePlan.guidedPrompts(setCount: restored.draft.sets.count)
        XCTAssertEqual(prompts[restored.stepIndex], .review)
        XCTAssertEqual(restored.draft.painDuring, 2)
        XCTAssertTrue(restored.draft.includeWarmup)
        XCTAssertEqual(restored.draft.warmup.steps.count, 1)
    }

    func testOldHoldDraftsStayInTheStandardForm() {
        XCTAssertFalse(GuidedCheckpointing.resumesInGuidedForm(sessionType: .isometrics, stepIndex: nil))
        XCTAssertTrue(GuidedCheckpointing.resumesInGuidedForm(sessionType: .hsrStrength, stepIndex: nil))
        XCTAssertTrue(GuidedCheckpointing.resumesInGuidedForm(sessionType: .isometrics, stepIndex: 2))
    }

    // MARK: Background autosave

    func testAutosaveOnlyWhenLeavingWithChanges() {
        XCTAssertTrue(GuidedCheckpointing.shouldAutosave(leavingForeground: true, changedSinceSave: true))
        XCTAssertTrue(GuidedCheckpointing.shouldAutosaveOnRecord(changedSinceSave: true))
        XCTAssertFalse(GuidedCheckpointing.shouldAutosaveOnRecord(changedSinceSave: false))
        // An untouched new log does not make an empty draft.
        XCTAssertFalse(GuidedCheckpointing.shouldAutosave(leavingForeground: true, changedSinceSave: false))
        XCTAssertFalse(GuidedCheckpointing.shouldAutosave(leavingForeground: false, changedSinceSave: true))
    }

    func testAutosavedCheckpointIsADraftNotASession() {
        var draft = plan()
        draft.sets[0].loadLbs = 55
        let saved = GuidedCheckpointing.checkpoint(draft, stepIndex: 2)
        let row = snapshot(of: saved, isDraft: true)
        XCTAssertFalse(row.isFinalized)
        XCTAssertTrue(TodayPlanner.recentMissingAfterPain(sessions: [row], now: day0.addingTimeInterval(120)).isEmpty)
    }


    func testAutosaveOnAddWarmupKeepsTheNewStep() {
        var draft = plan()
        draft.includeWarmup = true
        draft.warmup = WarmupPlan(steps: [], source: .blank)
        XCTAssertTrue(draft.warmup.addCommitted(.hold(seconds: 30, loadLbs: 10)))
        let saved = GuidedCheckpointing.checkpoint(draft, stepIndex: GuidedCheckpointing.warmupIndex)
        XCTAssertEqual(saved.resistanceSets.filter(\.isWarmup).count, 1)
        let restored = GuidedCheckpointing.restore(saved, onto: plan())
        XCTAssertEqual(restored.draft.warmup.steps.count, 1)
        XCTAssertEqual(restored.draft.warmup.steps[0].seconds, 30)
        XCTAssertEqual(restored.draft.warmup.steps[0].loadLbs, 10)
    }

    // MARK: Helpers

    private func snapshot(of checkpoint: GuidedCheckpoint, isDraft: Bool) -> TrainingSessionSnapshot {
        TrainingSessionSnapshot(
            date: day0,
            createdAt: day0.addingTimeInterval(60),
            sessionType: checkpoint.sessionType,
            response24h: .pending,
            decision: nil,
            resolvedAt: nil,
            snoozedUntil: nil,
            phase: checkpoint.phase,
            painDuring: checkpoint.painDuring,
            isDraft: isDraft,
            whatIDid: checkpoint.whatIDid,
            resistanceSets: checkpoint.resistanceSets
        )
    }

    private func prior(load: Double) -> TrainingSessionSnapshot {
        let date = calendar.date(byAdding: .day, value: -3, to: day0)!
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
            whatIDid: "Seated leg extension",
            resistanceSets: SessionPrefill.workSets(
                from: LoadPrescription(workingSets: 3, reps: 8, loadLbs: load),
                laterality: .bilateral
            )
        )
    }
}
