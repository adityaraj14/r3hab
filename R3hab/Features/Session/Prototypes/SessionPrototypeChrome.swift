import SwiftUI

enum PrototypePainColor {
    static func color(for score: Int) -> Color {
        let clamped = min(max(score, 0), 10)
        let t = Double(clamped) / 10
        return Color(
            red: 0.22 + 0.74 * t,
            green: 0.78 - 0.58 * t,
            blue: 0.28 - 0.18 * t
        )
    }
}

extension View {
    func prototypeScreen(identifier: String) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.canvas.ignoresSafeArea())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
    }
}

/// Step dots in the navigation bar. Tap a done dot to open that step.
/// Steps after the first unfinished step do not respond.
struct PrototypeProgressDots: View {
    var count: Int
    var index: Int
    /// The first unfinished step.
    var furthest: Int
    var onSelect: (Int) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { step in
                dot(step)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(SessionPrototypeAccessibility.progress)
        .accessibilityLabel("Step \(index + 1) of \(count)")
    }

    @ViewBuilder
    private func dot(_ step: Int) -> some View {
        if let target = SessionPrototypePlan.jumpTarget(tapped: step, current: index, furthest: furthest) {
            Button { onSelect(target) } label: { capsule(step) }
                .buttonStyle(.plain)
                .accessibilityIdentifier(SessionPrototypeAccessibility.progressStep(step))
                .accessibilityLabel("Step \(step + 1)")
                .accessibilityHint("Open this step.")
        } else {
            capsule(step)
                .accessibilityElement()
                .accessibilityIdentifier(SessionPrototypeAccessibility.progressStep(step))
                .accessibilityLabel("Step \(step + 1)")
                .accessibilityAddTraits(step == index ? .isSelected : [])
        }
    }

    private func capsule(_ step: Int) -> some View {
        Capsule()
            .fill(fill(for: step))
            .frame(width: step == index ? 18 : 6, height: 6)
            // A larger tap area than the dot.
            .padding(.horizontal, 4)
            .frame(height: 44)
            .contentShape(Rectangle())
    }

    private func fill(for step: Int) -> Color {
        if step == index { return AppTheme.gold }
        if SessionPrototypePlan.isStepDone(step, furthest: furthest) { return Color.white.opacity(0.85) }
        return AppTheme.quietFill
    }
}

/// Horizontal step progress for the warm-up steps and the working sets.
/// Numbered nodes joined by a line. A done node shows a check and opens its step.
/// An optional small "+" node at the end adds a step.
struct PrototypeSetStepper: View {
    var count: Int
    /// The node on screen now, if any.
    var current: Int?
    var isDone: (Int) -> Bool
    /// "Set" or "Warm-up". Used in the VoiceOver labels.
    var noun: String = "Set"
    /// Prefix for the node ids, for example "prototype-guided-set".
    var identifierPrefix: String = "prototype-guided-set"
    var onSelect: (Int) -> Void = { _ in }
    var onAdd: (() -> Void)?
    var addIdentifier: String?

    var body: some View {
        let total = max(count, 1)
        HStack(spacing: 0) {
            ForEach(0..<total, id: \.self) { i in
                if i > 0 { connector(done: isDone(i - 1)) }
                node(i)
            }
            if let onAdd {
                connector(done: false)
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.gold)
                        .frame(width: 22, height: 22)
                        .background(Circle().strokeBorder(AppTheme.gold.opacity(0.6), lineWidth: 1.5))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a \(noun.lowercased()) step")
                .accessibilityIdentifier(addIdentifier ?? "\(identifierPrefix)-add")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifierPrefix)-stepper")
    }

    private func connector(done: Bool) -> some View {
        Rectangle()
            .fill(done ? AppTheme.gold.opacity(0.85) : AppTheme.quietStroke)
            .frame(width: 16, height: 2)
    }

    @ViewBuilder
    private func node(_ i: Int) -> some View {
        let isCurrent = current == i
        let done = isDone(i)
        if done && !isCurrent {
            Button { onSelect(i) } label: { circle(i, isCurrent: false, done: true) }
                .buttonStyle(.plain)
                .accessibilityLabel("\(noun) \(i + 1), done")
                .accessibilityHint("Open this step.")
                .accessibilityIdentifier("\(identifierPrefix)-node-\(i + 1)")
        } else {
            circle(i, isCurrent: isCurrent, done: done)
                .accessibilityElement()
                .accessibilityLabel(isCurrent ? "\(noun) \(i + 1), current" : "\(noun) \(i + 1), not done")
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
                .accessibilityIdentifier("\(identifierPrefix)-node-\(i + 1)")
        }
    }

    private func circle(_ i: Int, isCurrent: Bool, done: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(isCurrent ? AppTheme.gold : AppTheme.quietStroke, lineWidth: isCurrent ? 2.5 : 1.5)
                .background(Circle().fill(fill(done: done, isCurrent: isCurrent)))
            if done && !isCurrent {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
            } else {
                Text("\(i + 1)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(isCurrent || done ? AppTheme.ink : AppTheme.quiet)
            }
        }
        .frame(width: 28, height: 28)
        .frame(height: 44)
        .contentShape(Rectangle())
    }

    private func fill(done: Bool, isCurrent: Bool) -> Color {
        if isCurrent { return AppTheme.gold }
        if done { return AppTheme.gold.opacity(0.85) }
        return AppTheme.quietFill
    }
}

struct PrototypePainReadout: View {
    var value: Int?

    /// Shows nothing until a score is selected.
    var body: some View {
        if let value {
            Text(String(value))
                .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(PrototypePainColor.color(for: value))
                .accessibilityHidden(true)
        }
    }
}

struct PrototypePainChips: View {
    @Binding var value: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pain during")
                .font(.headline)
                .foregroundStyle(AppTheme.ivory)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(0...10, id: \.self) { score in
                    chip(score)
                }
            }
            Text(SessionPrototypePlan.painDuringNote)
                .font(.footnote)
                .foregroundStyle(AppTheme.quiet)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chip(_ score: Int) -> some View {
        let selected = value == score
        return Button {
            value = score
            Haptics.light()
        } label: {
            Text("\(score)")
                .font(.title3.weight(.bold).monospacedDigit())
                .frame(maxWidth: .infinity, minHeight: 56)
                .foregroundStyle(labelColor(score: score, selected: selected))
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? PrototypePainColor.color(for: score) : AppTheme.quietFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(PrototypePainColor.color(for: score), lineWidth: selected ? 0 : 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(SessionPrototypeAccessibility.painChip(score))
        .accessibilityLabel("Pain during \(score)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func labelColor(score: Int, selected: Bool) -> Color {
        guard selected else { return PrototypePainColor.color(for: score) }
        return score >= 7 ? .white : AppTheme.ink
    }
}
