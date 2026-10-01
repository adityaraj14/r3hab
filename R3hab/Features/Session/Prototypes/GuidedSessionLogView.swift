import SwiftUI

/// One question per card. Prefill is the engine target, so a set is usually one tap.
struct GuidedSessionLogView: View {
    @Binding var draft: SessionPrototypeDraft
    var spacingWarning: String?
    var onSave: () -> Void

    @State private var index = 0

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
                if prompt == .review || prompt == .notes || prompt == .pain {
                    ScrollView {
                        stepBody
                            .padding(.horizontal, 20)
                            .padding(.vertical, 24)
                    }
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
        }
        .simultaneousGesture(swipe)
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
        VStack(spacing: 18) {
            Text("Warm-up done?")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.ivory)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedWarmup)
            Text(draft.warmupLine)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppTheme.quiet)
            VStack(spacing: 12) {
                Button("Yes") {
                    draft.includeWarmup = true
                    advance()
                }
                .buttonStyle(.primaryAction)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedWarmupYes)
                Button {
                    draft.includeWarmup = false
                    advance()
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.quietAction)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedWarmupSkip)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func setStep(_ setIndex: Int) -> some View {
        let set = draft.sets.indices.contains(setIndex) ? draft.sets[setIndex] : nil
        return VStack(spacing: 16) {
            Text("Set \(setIndex + 1) of \(max(draft.sets.count, 1))")
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.gold)
                .accessibilityIdentifier(SessionPrototypeAccessibility.guidedSet(setIndex))
            if let set {
                PrototypeDoseReadout(
                    reps: set.reps,
                    loadLbs: set.loadLbs,
                    identifier: "prototype-guided-dose-\(setIndex + 1)"
                )
                Text(draft.perSetTargetLine)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.quiet)
                HStack(alignment: .top, spacing: 8) {
                    PrototypeAdjustRow(
                        title: "Reps",
                        value: "\(set.reps)",
                        minusIdentifier: "prototype-guided-set-\(setIndex + 1)-reps-minus",
                        plusIdentifier: "prototype-guided-set-\(setIndex + 1)-reps-plus",
                        onMinus: { updateSet(setIndex) { $0.reps = SessionPrototypePlan.bumpReps($0.reps, by: -1) } },
                        onPlus: { updateSet(setIndex) { $0.reps = SessionPrototypePlan.bumpReps($0.reps, by: 1) } }
                    )
                    PrototypeAdjustRow(
                        title: "Load",
                        value: set.loadLbs.map { LoadCopy.formatted($0) } ?? "—",
                        minusIdentifier: "prototype-guided-set-\(setIndex + 1)-load-minus",
                        plusIdentifier: "prototype-guided-set-\(setIndex + 1)-load-plus",
                        onMinus: { updateSet(setIndex) { $0.loadLbs = SessionPrototypePlan.bumpLoad($0.loadLbs, by: -SessionPrototypePlan.loadStep) } },
                        onPlus: { updateSet(setIndex) { $0.loadLbs = SessionPrototypePlan.bumpLoad($0.loadLbs, by: SessionPrototypePlan.loadStep) } }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
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
                reviewRow("Warm-up", draft.includeWarmup ? draft.warmupLine : "Skipped")
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
                EmptyView()
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
        guard index + 1 < prompts.count else { return }
        index += 1
        Haptics.light()
    }

    private func back() {
        guard index > 0 else { return }
        index -= 1
    }
}
