import SwiftUI

/// One tap when the session matched the plan. Adjust opens per-set chips.
struct QuickSessionLogView: View {
    @Binding var draft: SessionPrototypeDraft
    var spacingWarning: String?
    var onSave: () -> Void

    @State private var stage: Stage = .ask
    @State private var adjusted = false

    private enum Stage: Equatable {
        case ask
        case adjust
        case pain
    }

    var body: some View {
        VStack(spacing: 0) {
            switch stage {
            case .ask:
                ask
            case .adjust:
                adjust
            case .pain:
                pain
            }
        }
        .prototypeScreen(identifier: SessionPrototypeAccessibility.screen(.quick))
    }

    private var ask: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Did you do today's plan?")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.ivory)
                    Text("\(draft.planLine)?")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.gold)
                        .minimumScaleFactor(0.5)
                        .lineLimit(3)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(SessionPrototypeAccessibility.quickPlan)
                .accessibilityLabel(draft.quickQuestion)
                if let spacingWarning {
                    Text(spacingWarning)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    adjusted = false
                    stage = .pain
                    Haptics.light()
                } label: {
                    Text("Yes, as planned")
                        .padding(.vertical, 6)
                }
                .buttonStyle(.primaryAction)
                .accessibilityIdentifier(SessionPrototypeAccessibility.quickYes)
                Button {
                    adjusted = true
                    stage = .adjust
                    Haptics.light()
                } label: {
                    Text("Adjust")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.quietAction)
                .accessibilityIdentifier(SessionPrototypeAccessibility.quickAdjust)
            }
            .padding(20)
            .posterCard()
            .padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
    }

    private var adjust: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Adjust sets")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppTheme.ivory)
                        .accessibilityIdentifier(SessionPrototypeAccessibility.quickAdjustPanel)
                    Text(draft.planLine)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.quiet)
                    ForEach(Array(draft.sets.enumerated()), id: \.element.id) { offset, set in
                        setCard(offset: offset, set: set)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            VStack(spacing: 10) {
                Button("Next") {
                    stage = .pain
                    Haptics.light()
                }
                .buttonStyle(.primaryAction)
                .accessibilityIdentifier(SessionPrototypeAccessibility.quickAdjustDone)
                Button("Back") { stage = .ask }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.quiet)
                    .accessibilityIdentifier(SessionPrototypeAccessibility.back)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }

    private func setCard(offset: Int, set: PrototypeSetDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set \(offset + 1)")
                .font(.headline)
                .foregroundStyle(AppTheme.ivory)
            Text("Reps")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
            chipRow(SessionPrototypePlan.repChoices(around: draft.target.reps).map { choice in
                Chip(
                    title: "\(choice)",
                    selected: set.reps == choice,
                    identifier: SessionPrototypeAccessibility.quickReps(set: offset + 1, reps: choice)
                ) {
                    updateSet(offset) { $0.reps = choice }
                }
            })
            Text("Load")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
            chipRow(SessionPrototypePlan.loadChoices(around: draft.target.loadLbs).map { choice in
                Chip(
                    title: choice.map { LoadCopy.formatted($0) } ?? "—",
                    selected: loadsMatch(set.loadLbs, choice),
                    identifier: SessionPrototypeAccessibility.quickLoad(
                        set: offset + 1,
                        token: SessionPrototypePlan.loadToken(choice)
                    )
                ) {
                    updateSet(offset) { $0.loadLbs = choice }
                }
            })
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .posterCard()
    }

    private struct Chip {
        var title: String
        var selected: Bool
        var identifier: String
        var action: () -> Void
    }

    private func chipRow(_ chips: [Chip]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                PrototypeValueChip(
                    title: chip.title,
                    selected: chip.selected,
                    identifier: chip.identifier,
                    action: chip.action
                )
            }
        }
    }

    private var pain: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    Text(draft.planLine)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppTheme.gold)
                    PrototypePainReadout(value: draft.painDuring)
                    PrototypePainChips(value: $draft.painDuring)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(SessionPrototypeAccessibility.quickPain)
            VStack(spacing: 10) {
                Button("Save") { onSave() }
                    .buttonStyle(.primaryAction)
                    .disabled(draft.painDuring == nil)
                    .accessibilityIdentifier(SessionPrototypeAccessibility.save)
                Button("Back") {
                    stage = adjusted ? .adjust : .ask
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
                .accessibilityIdentifier(SessionPrototypeAccessibility.back)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }

    private func updateSet(_ index: Int, _ change: (inout PrototypeSetDraft) -> Void) {
        guard draft.sets.indices.contains(index) else { return }
        change(&draft.sets[index])
    }

    private func loadsMatch(_ left: Double?, _ right: Double?) -> Bool {
        switch (left, right) {
        case (nil, nil):
            return true
        case let (a?, b?):
            return abs(a - b) < 0.001
        default:
            return false
        }
    }
}
