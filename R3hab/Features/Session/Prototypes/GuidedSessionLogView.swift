import SwiftUI

/// The session recorder. One question per card. Prefill is the engine target, so a set is usually one tap.
struct GuidedSessionLogView: View {
    @Binding var draft: SessionPrototypeDraft
    /// Current step. The host keeps it, so a draft save stores it and a resume opens there.
    @Binding var index: Int
    var spacingWarning: String?
    var onSave: () -> Void
    /// Writes the draft checkpoint after a warm-up add/remove or a working-set record.
    var onCheckpointSave: () -> Void = {}

    @FocusState private var notesFocused: Bool
    /// Rulers for the next warm-up set. Not stored until "Add warm-up set".
    @State private var warmupComposer = WarmupComposer.empty

    private var isSetPrompt: Bool {
        if case .set = prompt { return true }
        return false
    }

    private var prompts: [GuidedPrompt] {
        SessionPrototypePlan.guidedPrompts(setCount: draft.sets.count)
    }

    private var prompt: GuidedPrompt {
        let steps = prompts
        guard !steps.isEmpty else { return .exercise }
        let safe = min(max(index, 0), steps.count - 1)
        return steps[safe]
    }

    var body: some View {
        VStack(spacing: 0) {
            PrototypeProgressDots(count: max(prompts.count, 1), index: min(index, max(prompts.count - 1, 0)))
                .padding(.top, 12)
            Group {
                if prompt == .review || prompt == .notes || prompt == .pain || prompt == .warmup {
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
                    // Scrolled content goes under the buttons. The line shows the edge.
                    Rectangle().fill(AppTheme.cardHairline).frame(height: 1)
                        .opacity(prompt == .warmup || prompt == .review ? 1 : 0)
                }
        }
        // The set screen rulers use drags, so the step swipe is off there.
        .simultaneousGesture(swipe, including: isSetPrompt ? .subviews : .all)
        .toolbar {
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
                forward()
            } else if horizontal >= 48 {
                back()
            }
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch prompt {
        case .exercise:
            exerciseStep
        case .warmup:
            warmupStep
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

    private var warmupStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Warm-up")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.ivory)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedWarmup)
            Text(draft.warmup.source.label)
                .font(.caption.weight(.bold))
                .foregroundStyle(draft.warmup.source == .lastSession ? AppTheme.ink : AppTheme.ivory)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    draft.warmup.source == .lastSession ? AppTheme.gold : AppTheme.quietFill,
                    in: Capsule()
                )
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedWarmupSource)
            Text(draft.warmup.steps.isEmpty
                 ? "Set the rulers. Then add the warm-up set."
                 : "Add another warm-up, or select Warm-up done.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.quiet)

            ForEach(Array(draft.warmup.steps.enumerated()), id: \.element.id) { offset, step in
                finishedWarmupRow(offset, step)
            }

            if draft.warmup.steps.count < WarmupPlan.maxSteps {
                warmupComposerCard
                Button {
                    addWarmupSet()
                } label: {
                    Label(
                        draft.warmup.steps.isEmpty ? "Add warm-up set" : "Add another warm-up",
                        systemImage: "plus"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primaryAction)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedWarmupAdd)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func finishedWarmupRow(_ offset: Int, _ step: WarmupStep) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Warm-up \(offset + 1)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.quiet)
                Text(step.line)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ivory)
                if step.fromLastSession {
                    Text("From last session")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.gold)
                }
            }
            Spacer(minLength: 4)
            Button {
                removeWarmupSet(id: step.id)
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.quiet)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove warm-up \(offset + 1)")
            .accessibilityIdentifier(SessionPrototypeAccessibility.warmupStep(offset, "remove"))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .posterCard()
        .accessibilityIdentifier(SessionPrototypeAccessibility.warmupStep(offset))
    }

    private var warmupComposerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 0) {
                ForEach(WarmupStep.Kind.allCases, id: \.self) { kind in
                    composerKindButton(kind)
                }
            }
            .background(AppTheme.quietFill, in: Capsule())
            .accessibilityIdentifier("prototype-guided-warmup-kind")

            if warmupComposer.kind == .hold {
                holdRuler
            } else {
                warmupRepsRuler
            }
            warmupLoadRuler
        }
    }

    private func composerKindButton(_ kind: WarmupStep.Kind) -> some View {
        let selected = warmupComposer.kind == kind
        return Button {
            warmupComposer.selectKind(kind)
            Haptics.light()
        } label: {
            Text(kind.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(selected ? AppTheme.ink : AppTheme.ivory)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .frame(maxWidth: .infinity)
                .background(selected ? AppTheme.gold : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(SessionPrototypeAccessibility.warmupStep(0, kind.rawValue))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var holdRuler: some View {
        let index = WarmupPlan.holdSecondsIndex(warmupComposer.seconds)
        let target = WarmupPlan.holdSecondsIndex(WarmupPlan.holdSeconds)
        return PrototypeRulerWheel(
            title: "Hold",
            valueText: "\(warmupComposer.seconds)",
            unit: "s",
            deltaText: index == target ? "Default" : "\(warmupComposer.seconds) s",
            onTarget: index == target,
            count: WarmupPlan.holdSecondsIndexCount,
            index: index,
            targetIndex: target,
            isMajor: { WarmupPlan.holdSeconds(atIndex: $0) % 15 == 0 },
            label: { "\(WarmupPlan.holdSeconds(atIndex: $0))" },
            identifier: "prototype-guided-warmup-hold-ruler",
            onSelect: { warmupComposer.seconds = WarmupPlan.holdSeconds(atIndex: $0) }
        )
    }

    private var warmupRepsRuler: some View {
        PrototypeRulerWheel(
            title: "Reps",
            valueText: "\(warmupComposer.reps)",
            unit: warmupComposer.reps == 1 ? "rep" : "reps",
            deltaText: warmupComposer.reps == WarmupPlan.defaultReps ? "Default" : "\(warmupComposer.reps)",
            onTarget: warmupComposer.reps == WarmupPlan.defaultReps,
            count: WarmupPlan.maxReps,
            index: warmupComposer.reps - 1,
            targetIndex: WarmupPlan.defaultReps - 1,
            isMajor: { ($0 + 1) % 5 == 0 },
            label: { "\($0 + 1)" },
            identifier: "prototype-guided-warmup-reps-ruler",
            onSelect: { warmupComposer.reps = $0 + 1 }
        )
    }

    private var warmupLoadRuler: some View {
        PrototypeRulerWheel(
            title: "Load",
            valueText: LoadCopy.formatted(warmupComposer.loadLbs ?? 0),
            unit: LoadCopy.unit,
            deltaText: (warmupComposer.loadLbs ?? 0) == 0 ? "No load" : LoadCopy.labeled(warmupComposer.loadLbs ?? 0),
            onTarget: (warmupComposer.loadLbs ?? 0) == 0,
            count: SessionPrototypePlan.loadIndexCount,
            index: SessionPrototypePlan.loadIndex(warmupComposer.loadLbs),
            targetIndex: 0,
            isMajor: { $0 % 2 == 0 },
            label: { LoadCopy.formatted(SessionPrototypePlan.load(atIndex: $0) ?? 0) },
            identifier: "prototype-guided-warmup-load-ruler",
            onSelect: { warmupComposer.loadLbs = SessionPrototypePlan.load(atIndex: $0) }
        )
    }

    private func addWarmupSet() {
        let step = warmupComposer.makeStep()
        guard draft.warmup.addCommitted(step) else { return }
        warmupComposer = WarmupComposer.afterAdding(step)
        Haptics.light()
        onCheckpointSave()
    }

    private func removeWarmupSet(id: UUID) {
        draft.warmup.removeStep(id: id)
        Haptics.light()
        onCheckpointSave()
    }

    private func setStep(_ setIndex: Int) -> some View {
        let set = draft.sets.indices.contains(setIndex) ? draft.sets[setIndex] : nil
        let recommended = max(draft.target.workingSets, draft.sets.count, 1)
        return VStack(spacing: 14) {
            PrototypeSetStepper(
                total: recommended,
                filled: SessionPrototypePlan.setStepperFilled(currentSetIndex: setIndex, setCount: recommended),
                current: setIndex
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

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 10) {
            switch prompt {
            case .exercise:
                Button("Next") { advance() }
                    .buttonStyle(.primaryAction)
                    .accessibilityIdentifier(SessionPrototypeAccessibility.next)
            case .warmup:
                Button("Warm-up done") {
                    draft.includeWarmup = true
                    onCheckpointSave()
                    advance()
                }
                .buttonStyle(.primaryAction)
                .disabled(draft.warmup.steps.isEmpty)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedWarmupYes)
                Button("Skip warm-up") {
                    draft.includeWarmup = false
                    onCheckpointSave()
                    advance()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedWarmupSkip)
            case .set(let setIndex):
                setActions(setIndex)
            case .pain:
                if draft.painDuring != nil {
                    Button("Next") { advance() }
                        .buttonStyle(.primaryAction)
                        .accessibilityIdentifier(SessionPrototypeAccessibility.next)
                }
            case .notes:
                Button(notesAreEmpty ? "Skip" : "Next") { advance() }
                    .buttonStyle(.primaryAction)
                    .accessibilityIdentifier(SessionPrototypeAccessibility.next)
            case .review:
                Button("Save") { onSave() }
                    .buttonStyle(.primaryAction)
                    .disabled(draft.painDuring == nil)
                    .accessibilityIdentifier(SessionPrototypeAccessibility.save)
            }
            if index > 0 {
                Button("Back", action: back)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.quiet)
                    .accessibilityIdentifier(SessionPrototypeAccessibility.back)
            }
        }
    }

    @ViewBuilder
    private func setActions(_ setIndex: Int) -> some View {
        let matches = draft.sets.indices.contains(setIndex)
            && draft.sets[setIndex].matchesTarget(draft.target)
        if matches {
            Button("Same as target") { confirmTarget(setIndex) }
                .buttonStyle(.primaryAction)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedSame)
        } else {
            Button("Same as target") { confirmTarget(setIndex) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedSame)
            Button("Next") { recordWorkingSetAndAdvance() }
                .buttonStyle(.primaryAction)
                .accessibilityIdentifier(SessionPrototypeAccessibility.next)
        }
    }

    private func recordWorkingSetAndAdvance() {
        onCheckpointSave()
        advance()
    }

    private var notesAreEmpty: Bool {
        draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func updateSet(_ setIndex: Int, _ change: (inout PrototypeSetDraft) -> Void) {
        guard draft.sets.indices.contains(setIndex) else { return }
        change(&draft.sets[setIndex])
    }

    private func confirmTarget(_ setIndex: Int) {
        guard draft.sets.indices.contains(setIndex) else { return }
        draft.sets[setIndex] = draft.sets[setIndex].aligned(to: draft.target)
        recordWorkingSetAndAdvance()
    }

    private func forward() {
        switch prompt {
        case .review, .warmup:
            return
        case .pain:
            guard draft.painDuring != nil else { return }
            advance()
        default:
            advance()
        }
    }

    private func advance() {
        notesFocused = false
        guard index + 1 < prompts.count else { return }
        index += 1
        Haptics.light()
    }

    private func back() {
        notesFocused = false
        guard index > 0 else { return }
        index -= 1
    }
}
