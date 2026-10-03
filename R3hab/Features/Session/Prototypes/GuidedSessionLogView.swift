import SwiftUI

/// One question per card. Prefill is the engine target, so a set is usually one tap.
struct GuidedSessionLogView: View {
    @Binding var draft: SessionPrototypeDraft
    var spacingWarning: String?
    var onSave: () -> Void

    @State private var index = 0
    @FocusState private var notesFocused: Bool

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
        .prototypeScreen(identifier: SessionPrototypeAccessibility.screen(.guided))
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
            Text("Change the values if necessary. Then do the warm-up.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.quiet)
            ForEach(Array(draft.warmup.steps.enumerated()), id: \.element.id) { offset, step in
                warmupCard(offset, step)
            }
            if draft.warmup.steps.count < WarmupPlan.maxSteps {
                Button {
                    draft.warmup.addStep()
                    Haptics.light()
                } label: {
                    Label("Add step", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.quietAction)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedWarmupAdd)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func warmupCard(_ offset: Int, _ step: WarmupStep) -> some View {
        let ids = { (part: String) in SessionPrototypeAccessibility.warmupStep(offset, part) }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Step \(offset + 1)")
                        .font(.headline)
                        .foregroundStyle(AppTheme.ivory)
                    if step.fromLastSession {
                        Text("From last session")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.gold)
                            .accessibilityIdentifier(ids("from-last"))
                    }
                }
                Spacer(minLength: 4)
                HStack(spacing: 0) {
                    ForEach(WarmupStep.Kind.allCases, id: \.self) { kind in
                        kindButton(kind, step: step, identifier: ids(kind.rawValue))
                    }
                }
                .background(AppTheme.quietFill, in: Capsule())
                Button {
                    draft.warmup.removeStep(id: step.id)
                    Haptics.light()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.quiet)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(ids("remove"))
                .accessibilityLabel("Remove step \(offset + 1)")
            }
            HStack(spacing: 12) {
                if step.kind == .hold {
                    PrototypeMiniStepper(
                        title: "Seconds",
                        value: "\(step.seconds)",
                        identifier: ids("amount"),
                        onMinus: { editStep(step) { $0.seconds = max($0.seconds - WarmupPlan.holdSecondsStep, 5) } },
                        onPlus: { editStep(step) { $0.seconds = min($0.seconds + WarmupPlan.holdSecondsStep, 120) } }
                    )
                } else {
                    PrototypeMiniStepper(
                        title: "Reps",
                        value: "\(step.reps)",
                        identifier: ids("amount"),
                        onMinus: { editStep(step) { $0.reps = max($0.reps - 1, 1) } },
                        onPlus: { editStep(step) { $0.reps = min($0.reps + 1, 20) } }
                    )
                }
                PrototypeMiniStepper(
                    title: "Load (\(LoadCopy.unit))",
                    value: step.loadLbs.map { LoadCopy.formatted($0) } ?? "0",
                    identifier: ids("load"),
                    onMinus: { editStep(step) { $0.loadLbs = SessionPrototypePlan.load($0.loadLbs, ticks: -1) } },
                    onPlus: { editStep(step) { $0.loadLbs = SessionPrototypePlan.load($0.loadLbs, ticks: 1) } }
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .posterCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(SessionPrototypeAccessibility.warmupStep(offset))
    }

    private func kindButton(_ kind: WarmupStep.Kind, step: WarmupStep, identifier: String) -> some View {
        let selected = step.kind == kind
        return Button {
            guard !selected else { return }
            editStep(step) { $0.kind = kind }
            Haptics.light()
        } label: {
            Text(kind.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(selected ? AppTheme.ink : AppTheme.ivory)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(selected ? AppTheme.gold : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func editStep(_ step: WarmupStep, _ change: (inout WarmupStep) -> Void) {
        draft.warmup.update(id: step.id, change)
    }

    private func setStep(_ setIndex: Int) -> some View {
        let set = draft.sets.indices.contains(setIndex) ? draft.sets[setIndex] : nil
        return VStack(spacing: 14) {
            Text("Set \(setIndex + 1) of \(max(draft.sets.count, 1))")
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
                    advance()
                }
                .buttonStyle(.primaryAction)
                .disabled(draft.warmup.steps.isEmpty)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedWarmupYes)
                Button("Skip warm-up") {
                    draft.includeWarmup = false
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
            Button("Next") { advance() }
                .buttonStyle(.primaryAction)
                .accessibilityIdentifier(SessionPrototypeAccessibility.next)
        }
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
        advance()
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
