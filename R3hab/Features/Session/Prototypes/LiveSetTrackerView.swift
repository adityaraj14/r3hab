import SwiftUI

/// Log the set you are doing. Done starts a rest clock, then the next prefilled set.
struct LiveSetTrackerView: View {
    @Binding var draft: SessionPrototypeDraft
    var spacingWarning: String?
    var onSave: () -> Void

    @State private var completed = 0
    @State private var stage: Stage = .working
    @State private var restUntil: Date?
    @State private var sliderValue = 0.0

    private enum Stage: Equatable {
        case working
        case resting
        case pain
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 8)
            Group {
                switch stage {
                case .working:
                    working
                case .resting:
                    resting
                case .pain:
                    pain
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .prototypeScreen(identifier: SessionPrototypeAccessibility.screen(.live))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottom
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .task(id: restUntil) {
            await finishRestIfNeeded()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(draft.exerciseTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
            if stage == .pain {
                Text("Pain during")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.ivory)
                    .accessibilityIdentifier(SessionPrototypeAccessibility.livePain)
            } else {
                Text(stage == .resting ? "Rest" : "Set \(min(completed + 1, max(draft.sets.count, 1))) of \(max(draft.sets.count, 1))")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.ivory)
            }
            PrototypeSetBeads(count: draft.sets.count, completed: completed)
        }
        .frame(maxWidth: .infinity)
    }

    private var working: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            if draft.sets.indices.contains(completed) {
                let set = draft.sets[completed]
                PrototypeDoseReadout(
                    reps: set.reps,
                    loadLbs: set.loadLbs,
                    identifier: SessionPrototypeAccessibility.liveDose
                )
                Text(draft.perSetTargetLine)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.quiet)
                HStack(alignment: .top, spacing: 8) {
                    PrototypeAdjustRow(
                        title: "Reps",
                        value: "\(set.reps)",
                        minusIdentifier: SessionPrototypeAccessibility.liveRepsMinus,
                        plusIdentifier: SessionPrototypeAccessibility.liveRepsPlus,
                        onMinus: { updateActive { $0.reps = SessionPrototypePlan.bumpReps($0.reps, by: -1) } },
                        onPlus: { updateActive { $0.reps = SessionPrototypePlan.bumpReps($0.reps, by: 1) } }
                    )
                    PrototypeAdjustRow(
                        title: "Load",
                        value: set.loadLbs.map { LoadCopy.formatted($0) } ?? "—",
                        minusIdentifier: SessionPrototypeAccessibility.liveLoadMinus,
                        plusIdentifier: SessionPrototypeAccessibility.liveLoadPlus,
                        onMinus: { updateActive { $0.loadLbs = SessionPrototypePlan.bumpLoad($0.loadLbs, by: -SessionPrototypePlan.loadStep) } },
                        onPlus: { updateActive { $0.loadLbs = SessionPrototypePlan.bumpLoad($0.loadLbs, by: SessionPrototypePlan.loadStep) } }
                    )
                }
                .padding(.horizontal, 12)
            }
            Spacer(minLength: 0)
        }
    }

    private var resting: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(clock(remaining(at: context.date)))
                    .font(.system(size: 84, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(AppTheme.gold)
                    .accessibilityIdentifier(SessionPrototypeAccessibility.liveRest)
                    .accessibilityLabel("Rest \(clock(remaining(at: context.date)))")
            }
            Text("Set \(completed) logged")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ivory)
            if completed < draft.sets.count {
                Text("Next: set \(completed + 1)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.quiet)
            }
            Spacer(minLength: 0)
        }
    }

    private var pain: some View {
        ScrollView {
            VStack(spacing: 16) {
                PrototypePainReadout(value: draft.painDuring)
                Slider(
                    value: Binding(
                        get: { sliderValue },
                        set: { newValue in
                            let changed = abs(newValue - sliderValue) > 0.001
                            sliderValue = newValue
                            if changed {
                                draft.painDuring = Int(newValue.rounded())
                            }
                        }
                    ),
                    in: 0...10,
                    step: 1
                )
                .tint(draft.painDuring.map { PrototypePainColor.color(for: $0) } ?? AppTheme.quiet)
                .accessibilityIdentifier(SessionPrototypeAccessibility.liveSlider)
                .accessibilityLabel("Pain during")
                PrototypePainChips(value: painBinding)
                if let spacingWarning {
                    Text(spacingWarning)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .onChange(of: draft.painDuring) { _, newValue in
            guard let newValue else { return }
            let snapped = Double(newValue)
            if abs(sliderValue - snapped) > 0.01 {
                sliderValue = snapped
            }
        }
    }

    private var painBinding: Binding<Int?> {
        Binding(
            get: { draft.painDuring },
            set: { newValue in
                draft.painDuring = newValue
                if let newValue {
                    sliderValue = Double(newValue)
                }
            }
        )
    }

    @ViewBuilder
    private var bottom: some View {
        switch stage {
        case .working:
            Button {
                doneSet()
            } label: {
                Text("Done set")
                    .padding(.vertical, 6)
            }
            .buttonStyle(.primaryAction)
            .accessibilityIdentifier(SessionPrototypeAccessibility.liveDone)
        case .resting:
            Button {
                skipRest()
            } label: {
                Text("Skip rest")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.quietAction)
            .accessibilityIdentifier(SessionPrototypeAccessibility.liveSkipRest)
        case .pain:
            Button("Save") { onSave() }
                .buttonStyle(.primaryAction)
                .disabled(draft.painDuring == nil)
                .accessibilityIdentifier(SessionPrototypeAccessibility.save)
        }
    }

    private func updateActive(_ change: (inout PrototypeSetDraft) -> Void) {
        guard draft.sets.indices.contains(completed) else { return }
        change(&draft.sets[completed])
    }

    private func doneSet() {
        guard draft.sets.indices.contains(completed) else { return }
        completed += 1
        Haptics.light()
        if completed < draft.sets.count {
            restUntil = Date().addingTimeInterval(TimeInterval(SessionPrototypePlan.restSeconds))
            stage = .resting
        } else {
            restUntil = nil
            stage = .pain
        }
    }

    private func skipRest() {
        restUntil = nil
        stage = .working
        Haptics.light()
    }

    private func remaining(at now: Date) -> Int {
        guard let restUntil else { return 0 }
        return max(0, Int(restUntil.timeIntervalSince(now).rounded(.up)))
    }

    private func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func finishRestIfNeeded() async {
        guard let until = restUntil else { return }
        let delay = until.timeIntervalSinceNow
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        guard !Task.isCancelled, restUntil == until else { return }
        restUntil = nil
        stage = .working
        Haptics.light()
    }
}
