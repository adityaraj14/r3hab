import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

/// Save (top bar) on each guided step, resume, older drafts, and background autosave.
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
        // The warm-up nodes are prefilled with the plan. Change the reps on node 2.
        XCTAssertGreaterThanOrEqual(draft.warmup.steps.count, 2)
        draft.warmup.update(id: draft.warmup.steps[1].id) { $0.reps = 5 }
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
        let prompts = source.prompts
        for (index, prompt) in prompts.enumerated() {
            var draft = source
            // On the warm-up steps, Next on the last warm-up step is not done yet.
            if index <= GuidedCheckpointing.lastWarmupIndex(source) { draft.includeWarmup = false }
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
        let firstSet = draft.prompts.firstIndex(of: .set(0))!
        let saved = GuidedCheckpointing.checkpoint(draft, stepIndex: firstSet)
        XCTAssertFalse(saved.resistanceSets.contains(where: \.isWarmup))
        let restored = GuidedCheckpointing.restore(saved, onto: plan())
        XCTAssertFalse(restored.draft.includeWarmup)
        XCTAssertEqual(restored.stepIndex, firstSet)
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
        XCTAssertEqual(base.warmup.steps.map(\.reps), [4])
        XCTAssertEqual(base.warmup.planned.map(\.reps), [4])
        var draft = base
        // Next on the one warm-up node.
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
        let last = filled().prompts.count - 1
        XCTAssertEqual(saved.stepIndex, last)
        saved.stepIndex = -4
        XCTAssertEqual(GuidedCheckpointing.restore(saved, onto: plan()).stepIndex, 0)
    }

    func testStepsAfterPainNeedAPainValue() {
        var draft = filled()
        draft.painDuring = nil
        let review = draft.prompts.count - 1
        let saved = GuidedCheckpointing.checkpoint(draft, stepIndex: review)
        let restored = GuidedCheckpointing.restore(saved, onto: plan())
        let painIndex = draft.prompts.firstIndex(of: .pain)!
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
        let prompts = restored.draft.prompts
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


    func testAutosaveOnPlusNodeKeepsTheExtraStep() {
        var draft = plan()
        XCTAssertTrue(draft.warmup.addStep())
        let extraIndex = GuidedCheckpointing.lastWarmupIndex(draft)
        let saved = GuidedCheckpointing.checkpoint(draft, stepIndex: extraIndex)
        XCTAssertEqual(saved.resistanceSets.filter(\.isWarmup).count, 4)
        let restored = GuidedCheckpointing.restore(saved, onto: plan())
        XCTAssertEqual(restored.draft.warmup.steps.count, 4)
        XCTAssertTrue(restored.draft.warmup.isExtra(at: 3))
        XCTAssertEqual(restored.stepIndex, extraIndex, "Resume opens on the extra step")
    }

    // MARK: Back, edit, delete

    /// Back goes one step back. The values stay, and the autosave keeps them. Nothing reverts.
    func testBackAutosaveKeepsTheValues() {
        var draft = plan()
        draft.includeWarmup = true
        let set2 = draft.prompts.firstIndex(of: .set(1))!
        // On set 2: change the load, then Back to set 1. The first unfinished step is still set 2.
        draft.sets[1].loadLbs = 60
        let saved = GuidedCheckpointing.checkpoint(draft, stepIndex: set2)
        let restored = GuidedCheckpointing.restore(saved, onto: plan())
        XCTAssertEqual(restored.draft.sets[1].loadLbs, 60, "Back does not revert the change")
        XCTAssertEqual(restored.draft.sets.map(\.loadLbs), draft.sets.map(\.loadLbs))
        XCTAssertEqual(restored.stepIndex, set2, "Resume opens at the first unfinished step")
    }

    func testBackOnStepOneSavesOnlyWhenThereIsSomethingToKeep() {
        // A new log with nothing entered: close, no draft.
        XCTAssertFalse(GuidedCheckpointing.savesDraftOnClose(rowExists: false, changedSinceSave: false))
        // A value was entered: save the draft, then close.
        XCTAssertTrue(GuidedCheckpointing.savesDraftOnClose(rowExists: false, changedSinceSave: true))
        // The draft row exists (a Next saved it, or this is a resume): save and close.
        XCTAssertTrue(GuidedCheckpointing.savesDraftOnClose(rowExists: true, changedSinceSave: false))
    }

    func testEditOnADoneWarmupStepIsSaved() {
        var draft = plan()
        draft.includeWarmup = true
        let firstSet = draft.prompts.firstIndex(of: .set(0))!
        // Reopen warm-up 1 from set 1 and change the hold.
        draft.warmup.update(id: draft.warmup.steps[0].id) { $0.seconds = 45 }
        let saved = GuidedCheckpointing.checkpoint(draft, stepIndex: firstSet)
        let restored = GuidedCheckpointing.restore(saved, onto: plan())
        XCTAssertEqual(restored.draft.warmup.steps[0].seconds, 45)
        XCTAssertTrue(restored.draft.includeWarmup)
        XCTAssertEqual(restored.stepIndex, firstSet)
    }

    func testDeleteOfADoneWarmupStepIsSaved() {
        var draft = plan()
        draft.includeWarmup = true
        let firstSet = draft.prompts.firstIndex(of: .set(0))!
        draft.warmup.removeStep(at: 0)
        let after = SessionPrototypePlan.afterDelete(deleted: 1, furthest: firstSet, count: draft.prompts.count)
        XCTAssertEqual(draft.prompts[after.current], .set(0), "After the delete, the first unfinished step is still set 1")
        let saved = GuidedCheckpointing.checkpoint(draft, stepIndex: after.furthest)
        XCTAssertEqual(saved.resistanceSets.filter(\.isWarmup).count, 2)
        let restored = GuidedCheckpointing.restore(saved, onto: plan())
        XCTAssertEqual(restored.draft.warmup.steps.map(\.reps), [3, 2])
        XCTAssertEqual(restored.draft.prompts[restored.stepIndex], .set(0))
    }

    // MARK: Helpers

    /// The user goes back to set 1 and changes it, then saves. The resume opens at the
    /// furthest step (set 3), and the change on set 1 stays.
    func testSaveFromAnEarlierStepKeepsTheFurthestStepAndTheEdit() {
        var draft = filled()
        let prompts = draft.prompts
        let set1 = prompts.firstIndex(of: .set(0))!
        let set3 = prompts.firstIndex(of: .set(2))!
        draft.painDuring = nil
        draft.notes = ""
        draft.sets[0].reps = draft.sets[0].reps + 2
        // The host saves the furthest step, not the step on screen.
        let saved = GuidedCheckpointing.checkpoint(draft, stepIndex: set3)
        let restored = GuidedCheckpointing.restore(saved, onto: plan())
        XCTAssertEqual(restored.stepIndex, set3)
        XCTAssertNotEqual(restored.stepIndex, set1)
        XCTAssertEqual(restored.draft.sets[0].reps, draft.sets[0].reps, "The edit on the earlier step does not revert")
    }

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
