import SwiftUI

/// The session recorder. One question per screen and one forward motion:
/// each step has one Next button. Back is the chevron in the navigation bar.
/// The rulers open at the plan, so a set is usually one tap.
struct GuidedSessionLogView: View {
    @Binding var draft: SessionPrototypeDraft
    /// Current step. The host keeps it.
    @Binding var index: Int
    /// The first unfinished step. Steps before it are done. A draft save stores it, so a resume opens there.
    @Binding var furthest: Int
    var spacingWarning: String?
    var onSave: () -> Void
    /// Writes the draft checkpoint. Called after each Next, Back, edit on a done step, and delete.
    var onCheckpointSave: () -> Void = {}
    /// Back on step 1. The host saves the draft (if there is something to keep) and closes.
    var onClose: () -> Void = {}

    @FocusState private var notesFocused: Bool

    private var hasRulers: Bool {
        switch prompt {
        case .set, .warmup: return true
        default: return false
        }
    }

    private var prompts: [GuidedPrompt] { draft.prompts }

    private var prompt: GuidedPrompt {
        let steps = prompts
        guard !steps.isEmpty else { return .exercise }
        let safe = min(max(index, 0), steps.count - 1)
        return steps[safe]
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if prompt == .review || prompt == .notes || prompt == .pain {
                    ScrollView {
                        stepBody
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        stepBody
                            .padding(.horizontal, 20)
                        Spacer(minLength: 0)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.18), value: index)
        }
        .prototypeScreen(identifier: SessionPrototypeAccessibility.screen)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity)
                .background(AppTheme.canvas.ignoresSafeArea(edges: .bottom))
                .overlay(alignment: .top) {
                    // Scrolled content goes under the button. The line shows the edge.
                    Rectangle().fill(AppTheme.cardHairline).frame(height: 1)
                        .opacity(prompt == .review ? 1 : 0)
                }
        }
        // The rulers use drags, so the step swipe is off on the warm-up and set steps.
        .simultaneousGesture(swipe, including: hasRulers ? .subviews : .all)
        .toolbar {
            // Back at the leading edge. On step 1 it saves the progress and closes the sheet.
            ToolbarItem(placement: .topBarLeading) {
                Button(action: back) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 32, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier(SessionPrototypeAccessibility.back)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { notesFocused = false }
            }
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 48).onEnded { value in
            let horizontal = value.translation.width
            let vertical = value.translation.height
            guard abs(horizontal) > abs(vertical) else { return }
            if horizontal <= -48 {
                next()
            } else if horizontal >= 48, index > 0 {
                back()
            }
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch prompt {
        case .exercise:
            exerciseStep
        case .warmup(let step):
            warmupStep(step)
        case .set(let setIndex):
            setStep(setIndex)
        case .pain:
            painStep
        case .notes:
            notesStep
        case .review:
            reviewStep
        }
    }

    private var exerciseStep: some View {
        VStack(spacing: 14) {
            Text(draft.exerciseTitle)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.ivory)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedExercise)
            Text(draft.planLine)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.gold)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
            Text(draft.stanceLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(AppTheme.gold, in: Capsule())
            Text(draft.reason)
                .font(.subheadline)
                .foregroundStyle(AppTheme.quiet)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Warm-up

    private func promptIndex(_ target: GuidedPrompt) -> Int? {
        prompts.firstIndex(of: target)
    }

    /// The warm-up was skipped: the user is past the warm-up steps and it is not included.
    private var warmupSkipped: Bool {
        !draft.includeWarmup && furthest > GuidedCheckpointing.lastWarmupIndex(draft)
    }

    private func warmupDone(_ step: Int) -> Bool {
        guard !warmupSkipped, let at = promptIndex(.warmup(step)) else { return false }
        return SessionPrototypePlan.isStepDone(at, furthest: furthest)
    }

    /// A done step or an extra step can be deleted. The last step stays.
    private func warmupDeletable(_ step: Int) -> Bool {
        draft.warmup.steps.count > 1 && (warmupDone(step) || draft.warmup.isExtra(at: step))
    }

    private func warmupStep(_ step: Int) -> some View {
        let total = draft.warmup.steps.count
        let value = draft.warmup.steps.indices.contains(step) ? draft.warmup.steps[step] : nil
        return VStack(spacing: 14) {
            PrototypeSetStepper(
                count: total,
                current: step,
                isDone: warmupDone,
                noun: "Warm-up",
                identifierPrefix: "prototype-guided-warmup",
                onSelect: { node in
                    if let at = promptIndex(.warmup(node)) { open(at) }
                },
                onAdd: total < WarmupPlan.maxSteps ? { addWarmupStep(from: step) } : nil,
                addIdentifier: SessionPrototypeAccessibility.guidedWarmupAdd
            )
            Text("Warm-up \(step + 1) of \(total)")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.gold)
                .accessibilityIdentifier(SessionPrototypeAccessibility.warmupStep(step))
            Text(warmupCaption(step))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedWarmupSource)
            if let value {
                HStack(spacing: 12) {
                    kindToggle(step, value)
                    Spacer(minLength: 8)
                    if warmupDeletable(step) {
                        Button(role: .destructive) {
                            deleteWarmupStep(step)
                        } label: {
                            Label("Delete set", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(SessionPrototypeAccessibility.guidedWarmupRemove)
                    } else {
                        Button("Skip warm-up", action: skipWarmup)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.quiet)
                            .accessibilityIdentifier(SessionPrototypeAccessibility.guidedWarmupSkip)
                    }
                }
                VStack(spacing: 12) {
                    if value.kind == .hold {
                        holdRuler(step, value)
                    } else {
                        warmupRepsRuler(step, value)
                    }
                    warmupLoadRuler(step, value)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(SessionPrototypeAccessibility.guidedWarmup)
    }

    private func warmupCaption(_ step: Int) -> String {
        if draft.warmup.isExtra(at: step) { return "Extra step" }
        return draft.warmup.source.label
    }

    private func kindToggle(_ step: Int, _ value: WarmupStep) -> some View {
        HStack(spacing: 0) {
            ForEach(WarmupStep.Kind.allCases, id: \.self) { kind in
                let selected = value.kind == kind
                Button {
                    updateWarmup(step) { $0.kind = kind }
                    Haptics.light()
                } label: {
                    Text(kind.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selected ? AppTheme.ink : AppTheme.ivory)
                        .frame(width: 72, height: 32)
                        .background(selected ? AppTheme.gold : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("prototype-guided-warmup-kind-\(kind.rawValue)")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .background(AppTheme.quietFill, in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("prototype-guided-warmup-kind")
    }

    /// The plan for this step. An extra step has no plan, so it is its own target.
    private func warmupTarget(_ step: Int, _ value: WarmupStep) -> WarmupStep {
        draft.warmup.target(at: step) ?? value
    }

    private func holdRuler(_ step: Int, _ value: WarmupStep) -> some View {
        let target = warmupTarget(step, value)
        let index = WarmupPlan.holdSecondsIndex(value.seconds)
        let targetIndex = WarmupPlan.holdSecondsIndex(target.seconds)
        return PrototypeRulerWheel(
            title: "Hold",
            valueText: "\(value.seconds)",
            unit: "s",
            deltaText: SessionPrototypePlan.secondsDelta(value.seconds, target: target.seconds),
            onTarget: index == targetIndex,
            count: WarmupPlan.holdSecondsIndexCount,
            index: index,
            targetIndex: targetIndex,
            isMajor: { WarmupPlan.holdSeconds(atIndex: $0) % 15 == 0 },
            label: { "\(WarmupPlan.holdSeconds(atIndex: $0))" },
            identifier: "prototype-guided-warmup-hold-ruler",
            onSelect: { position in updateWarmup(step) { $0.seconds = WarmupPlan.holdSeconds(atIndex: position) } }
        )
        .id("warmup-hold-\(step)")
    }

    private func warmupRepsRuler(_ step: Int, _ value: WarmupStep) -> some View {
        let target = warmupTarget(step, value)
        return PrototypeRulerWheel(
            title: "Reps",
            valueText: "\(value.reps)",
            unit: value.reps == 1 ? "rep" : "reps",
            deltaText: SessionPrototypePlan.repsDelta(value.reps, target: target.reps),
            onTarget: value.reps == target.reps,
            count: WarmupPlan.maxReps,
            index: value.reps - 1,
            targetIndex: target.reps - 1,
            isMajor: { ($0 + 1) % 5 == 0 },
            label: { "\($0 + 1)" },
            identifier: "prototype-guided-warmup-reps-ruler",
            onSelect: { position in updateWarmup(step) { $0.reps = position + 1 } }
        )
        .id("warmup-reps-\(step)")
    }

    private func warmupLoadRuler(_ step: Int, _ value: WarmupStep) -> some View {
        let target = warmupTarget(step, value)
        return PrototypeRulerWheel(
            title: "Load",
            valueText: LoadCopy.formatted(value.loadLbs ?? 0),
            unit: LoadCopy.unit,
            deltaText: (value.loadLbs ?? 0) == 0 && (target.loadLbs ?? 0) == 0
                ? "No load"
                : SessionPrototypePlan.loadDelta(value.loadLbs, target: target.loadLbs),
            onTarget: SessionPrototypePlan.loadIndex(value.loadLbs) == SessionPrototypePlan.loadIndex(target.loadLbs),
            count: SessionPrototypePlan.loadIndexCount,
            index: SessionPrototypePlan.loadIndex(value.loadLbs),
            targetIndex: SessionPrototypePlan.loadIndex(target.loadLbs),
            isMajor: { $0 % 2 == 0 },
            label: { LoadCopy.formatted(SessionPrototypePlan.load(atIndex: $0) ?? 0) },
            identifier: "prototype-guided-warmup-load-ruler",
            onSelect: { position in updateWarmup(step) { $0.loadLbs = SessionPrototypePlan.load(atIndex: position) } }
        )
        .id("warmup-load-\(step)")
    }

    /// A ruler or toggle change. On a done step, the change is saved at once.
    private func updateWarmup(_ step: Int, _ change: (inout WarmupStep) -> Void) {
        guard draft.warmup.steps.indices.contains(step) else { return }
        draft.warmup.update(id: draft.warmup.steps[step].id, change)
        if warmupDone(step) { onCheckpointSave() }
    }

    /// The "+" node. From the last step it opens the new step. From an earlier step the new node waits in line.
    private func addWarmupStep(from step: Int) {
        let wasLast = step == draft.warmup.steps.count - 1
        guard draft.warmup.addStep(),
              let newAt = promptIndex(.warmup(draft.warmup.steps.count - 1)) else { return }
        Haptics.light()
        // The new node goes in front of the working sets. Keep the same unfinished step.
        if furthest > newAt { furthest += 1 }
        if wasLast {
            draft.includeWarmup = true
            index = newAt
            furthest = max(furthest, newAt)
        }
        onCheckpointSave()
    }

    /// Delete set. No confirmation: the step is one value and the user can add it again with "+".
    private func deleteWarmupStep(_ step: Int) {
        guard warmupDeletable(step), let at = promptIndex(.warmup(step)) else { return }
        draft.warmup.removeStep(at: step)
        let next = SessionPrototypePlan.afterDelete(deleted: at, furthest: furthest, count: prompts.count)
        furthest = next.furthest
        index = next.current
        Haptics.light()
        onCheckpointSave()
    }

    /// Skip warm-up: no warm-up rows are saved. Go to the first working set.
    private func skipWarmup() {
        notesFocused = false
        draft.includeWarmup = false
        draft.warmup.removeExtraSteps()
        guard let first = promptIndex(.set(0)) ?? promptIndex(.pain) else { return }
        index = first
        furthest = max(furthest, first)
        Haptics.light()
        onCheckpointSave()
    }

    // MARK: Working sets

    private func setStep(_ setIndex: Int) -> some View {
        let set = draft.sets.indices.contains(setIndex) ? draft.sets[setIndex] : nil
        let recommended = max(draft.target.workingSets, draft.sets.count, 1)
        return VStack(spacing: 14) {
            PrototypeSetStepper(
                count: recommended,
                current: setIndex,
                isDone: setDone,
                onSelect: { node in
                    if let at = promptIndex(.set(node)) { open(at) }
                }
            )
            Text("Set \(setIndex + 1) of \(recommended)")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.gold)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedSet(setIndex))
            Text(draft.perSetTargetLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
                .accessibilityIdentifier("prototype-guided-dose-\(setIndex + 1)")
            if let set {
                VStack(spacing: 12) {
                    repsRuler(setIndex, set)
                    loadRuler(setIndex, set)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func setDone(_ setIndex: Int) -> Bool {
        guard let at = promptIndex(.set(setIndex)) else { return false }
        return SessionPrototypePlan.isStepDone(at, furthest: furthest)
    }

    private func repsRuler(_ setIndex: Int, _ set: PrototypeSetDraft) -> some View {
        PrototypeRulerWheel(
            title: "Reps",
            valueText: "\(set.reps)",
            unit: set.reps == 1 ? "rep" : "reps",
            deltaText: SessionPrototypePlan.repsDelta(set.reps, target: draft.target.reps),
            onTarget: set.reps == draft.target.reps,
            count: SessionPrototypePlan.maxReps,
            index: set.reps - 1,
            targetIndex: draft.target.reps - 1,
            isMajor: { ($0 + 1) % 5 == 0 },
            label: { "\($0 + 1)" },
            identifier: SessionPrototypeAccessibility.setRuler(set: setIndex, field: "reps"),
            onSelect: { position in updateSet(setIndex) { $0.reps = position + 1 } }
        )
        .id("reps-\(setIndex)")
    }

    private func loadRuler(_ setIndex: Int, _ set: PrototypeSetDraft) -> some View {
        PrototypeRulerWheel(
            title: "Load",
            valueText: LoadCopy.formatted(set.loadLbs ?? 0),
            unit: LoadCopy.unit,
            deltaText: SessionPrototypePlan.loadDelta(set.loadLbs, target: draft.target.loadLbs),
            onTarget: SessionPrototypePlan.loadIndex(set.loadLbs) == SessionPrototypePlan.loadIndex(draft.target.loadLbs),
            count: SessionPrototypePlan.loadIndexCount,
            index: SessionPrototypePlan.loadIndex(set.loadLbs),
            targetIndex: SessionPrototypePlan.loadIndex(draft.target.loadLbs),
            isMajor: { $0 % 2 == 0 },
            label: { LoadCopy.formatted(SessionPrototypePlan.load(atIndex: $0) ?? 0) },
            identifier: SessionPrototypeAccessibility.setRuler(set: setIndex, field: "load"),
            onSelect: { position in updateSet(setIndex) { $0.loadLbs = SessionPrototypePlan.load(atIndex: position) } }
        )
        .id("load-\(setIndex)")
    }

    private var painStep: some View {
        VStack(spacing: 16) {
            PrototypePainReadout(value: draft.painDuring)
            PrototypePainChips(value: $draft.painDuring)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(SessionPrototypeAccessibility.guidedPain)
    }

    private var notesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.ivory)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedNotes)
            Text("Optional")
                .font(.subheadline)
                .foregroundStyle(AppTheme.quiet)
            TextField("Notes", text: $draft.notes, axis: .vertical)
                .lineLimit(3...6)
                .focused($notesFocused)
                .padding(14)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.cardHairline, lineWidth: 1)
                )
                .accessibilityLabel("Notes")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Review")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.ivory)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedReview)
            VStack(alignment: .leading, spacing: 10) {
                reviewRow("Exercise", draft.exerciseTitle)
                if draft.includeWarmup && !draft.warmup.steps.isEmpty {
                    ForEach(Array(draft.warmup.steps.enumerated()), id: \.element.id) { offset, step in
                        reviewRow("Warm-up \(offset + 1)", step.line)
                    }
                } else {
                    reviewRow("Warm-up", "Skipped")
                }
                ForEach(Array(draft.sets.enumerated()), id: \.element.id) { offset, set in
                    reviewRow("Set \(offset + 1)", set.doseLabel)
                }
                reviewRow("Pain during", draft.painDuring.map(String.init) ?? "—")
                if !draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    reviewRow("Notes", draft.notes)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .posterCard()
            if let spacingWarning {
                Text(spacingWarning)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reviewRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(AppTheme.quiet)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(AppTheme.ivory)
        }
        .font(.subheadline.weight(.semibold))
    }

    /// One full-width button per step. Back is in the navigation bar.
    private var bottomBar: some View {
        if prompt == .review {
            return ActionFooter(primary: FooterAction(
                "Finish session",
                identifier: SessionPrototypeAccessibility.save,
                isEnabled: draft.painDuring != nil,
                action: onSave
            ))
        }
        return ActionFooter(primary: FooterAction(
            "Next",
            identifier: SessionPrototypeAccessibility.next,
            isEnabled: prompt != .pain || draft.painDuring != nil,
            action: next
        ))
    }

    private func updateSet(_ setIndex: Int, _ change: (inout PrototypeSetDraft) -> Void) {
        guard draft.sets.indices.contains(setIndex) else { return }
        change(&draft.sets[setIndex])
        if setDone(setIndex) { onCheckpointSave() }
    }

    // MARK: Navigation

    /// Next records the values on screen, goes forward, and saves the draft.
    private func next() {
        notesFocused = false
        switch prompt {
        case .review:
            return
        case .pain:
            guard draft.painDuring != nil else { return }
        case .warmup:
            draft.includeWarmup = true
        default:
            break
        }
        let target = SessionPrototypePlan.nextIndex(current: index, furthest: furthest, count: prompts.count)
        guard target != index else { return }
        index = target
        furthest = max(furthest, target)
        Haptics.light()
        onCheckpointSave()
    }

    /// Back goes one step back and saves the draft. It keeps all values.
    /// On step 1 the host saves the draft and closes the sheet.
    private func back() {
        notesFocused = false
        guard index > 0 else {
            onClose()
            return
        }
        index -= 1
        onCheckpointSave()
    }

    /// A tap on a done stepper node.
    private func open(_ step: Int) {
        guard let target = SessionPrototypePlan.nodeTarget(tapped: step, current: index, furthest: furthest) else { return }
        notesFocused = false
        index = target
        Haptics.light()
    }
}
