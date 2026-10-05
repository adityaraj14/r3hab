import Foundation

/// The values a guided draft writes to its `TrainingSession` draft row.
/// Pure value type, so the save and the restore are testable without SwiftData.
struct GuidedCheckpoint: Equatable, Sendable {
    var phase: RehabPhase
    var sessionType: SessionType
    var whatIDid: String
    /// `PainScore.notLogged` when the pain step has no value.
    var painDuring: Int
    var notes: String
    var resistanceSets: [ResistanceSet]
    /// Index into `SessionPrototypeDraft.prompts`. Nil on drafts from the older form.
    var stepIndex: Int?
}

enum GuidedCheckpointing {
    /// Position of the first warm-up step in the guided prompts.
    static let firstWarmupIndex = 1

    /// Position of the last warm-up step. Equal to the exercise step (0) when there is no warm-up.
    static func lastWarmupIndex(_ draft: SessionPrototypeDraft) -> Int {
        draft.warmup.steps.count
    }

    /// The draft row values for this point in the flow.
    /// Warm-up rows are kept while the user is on (or before) the warm-up steps,
    /// so edits stay. After that, only a warm-up the user did is kept.
    static func checkpoint(_ draft: SessionPrototypeDraft, stepIndex: Int) -> GuidedCheckpoint {
        let step = clamp(stepIndex, draft: draft)
        var rows: [ResistanceSet] = []
        if draft.includeWarmup || step <= lastWarmupIndex(draft) {
            rows.append(contentsOf: draft.warmup.resistanceSets())
        }
        var workOnly = draft
        workOnly.includeWarmup = false
        rows.append(contentsOf: workOnly.resistanceSets())
        return GuidedCheckpoint(
            phase: draft.phase,
            sessionType: draft.sessionType,
            whatIDid: draft.whatIDid(),
            painDuring: draft.painDuring ?? PainScore.notLogged,
            notes: draft.notes,
            resistanceSets: rows,
            stepIndex: step
        )
    }

    /// Puts the draft row values back on top of today's plan.
    /// `base` is the plan from `SessionPrototypePlan.make`. Values that the row
    /// does not have stay as the plan values.
    static func restore(
        _ checkpoint: GuidedCheckpoint,
        onto base: SessionPrototypeDraft
    ) -> (draft: SessionPrototypeDraft, stepIndex: Int) {
        var draft = base
        let rows = checkpoint.resistanceSets
        let warmupRows = rows.filter(\.isWarmup)
        let workRows = rows.filter { !$0.isWarmup }

        let pairs = SessionSummary.groupWorkSets(workRows)
        if !pairs.isEmpty {
            draft.sets = pairs.map { pair in
                PrototypeSetDraft(
                    id: pair.id,
                    reps: pair.reps ?? base.target.reps,
                    loadLbs: pair.leftLoad
                )
            }
        }

        let restoredSteps = WarmupPlan.steps(from: warmupRows)
        if !restoredSteps.isEmpty {
            let sameAsPlan = sameWarmup(restoredSteps, base.warmup.steps)
            if !sameAsPlan {
                draft.warmup = WarmupPlan(
                    steps: restoredSteps.map { var step = $0; step.fromLastSession = false; return step },
                    planned: base.warmup.planned,
                    source: base.warmup.source
                )
            }
        }

        draft.painDuring = PainScore.optional(checkpoint.painDuring)
        draft.notes = checkpoint.notes
        draft.phase = checkpoint.phase

        let prompts = draft.prompts
        let painIndex = prompts.firstIndex(of: .pain) ?? max(prompts.count - 3, 0)
        var step: Int
        if let saved = checkpoint.stepIndex {
            step = clamp(saved, draft: draft)
        } else {
            // Older drafts have no step. With a pain value, go to the review.
            // Else start at step 1.
            step = draft.painDuring != nil ? prompts.count - 1 : 0
        }
        // The steps after pain need a pain value.
        if draft.painDuring == nil, step > painIndex {
            step = painIndex
        }
        draft.includeWarmup = !restoredSteps.isEmpty && (checkpoint.stepIndex == nil || step > lastWarmupIndex(draft))
        return (draft, step)
    }

    /// A draft continues in the guided form when the guided form saved it,
    /// or when it is a strength session (the type the guided form saves).
    /// Older drafts of other types (holds, walks) stay in the standard form.
    static func resumesInGuidedForm(sessionType: SessionType, stepIndex: Int?) -> Bool {
        stepIndex != nil || sessionType == .hsrStrength
    }

    static func clamp(_ index: Int, draft: SessionPrototypeDraft) -> Int {
        let count = draft.prompts.count
        return min(max(index, 0), max(count - 1, 0))
    }

    /// Background autosave writes only when there is something new to keep:
    /// a value or the step changed after the sheet opened or after the last draft save.
    /// So an untouched new log does not make an empty draft.
    static func shouldAutosave(leavingForeground: Bool, changedSinceSave: Bool) -> Bool {
        leavingForeground && changedSinceSave
    }

    /// Save after each Next and each Back, when a value or the step changed.
    static func shouldAutosaveOnRecord(changedSinceSave: Bool) -> Bool {
        changedSinceSave
    }

    /// Back on step 1 closes the sheet. With no draft row and no entered value,
    /// it closes without a save, so no empty draft shows on Today.
    /// Else it saves the draft and then closes.
    static func savesDraftOnClose(rowExists: Bool, changedSinceSave: Bool) -> Bool {
        rowExists || changedSinceSave
    }

    private static func sameWarmup(_ a: [WarmupStep], _ b: [WarmupStep]) -> Bool {
        guard a.count == b.count else { return false }
        return zip(a, b).allSatisfy { lhs, rhs in
            lhs.resistanceSet().holdSeconds == rhs.resistanceSet().holdSeconds
                && lhs.resistanceSet().reps == rhs.resistanceSet().reps
                && lhs.resistanceSet().loadLbs == rhs.resistanceSet().loadLbs
        }
    }
}
