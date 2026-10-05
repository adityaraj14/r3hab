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

/// Step dots in the navigation bar. Tap a completed dot to go back to that step.
/// The current step and later steps do not respond.
struct PrototypeProgressDots: View {
    var count: Int
    var index: Int
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
        if let target = SessionPrototypePlan.jumpTarget(tapped: step, current: index) {
            Button { onSelect(target) } label: { capsule(step) }
                .buttonStyle(.plain)
                .accessibilityIdentifier(SessionPrototypeAccessibility.progressStep(step))
                .accessibilityLabel("Step \(step + 1)")
                .accessibilityHint("Go back to this step.")
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
        if step < index { return Color.white.opacity(0.85) }
        return AppTheme.quietFill
    }
}

/// Horizontal working-set progress. One node per recommended set. Filled nodes are logged.
struct PrototypeSetStepper: View {
    /// Recommended working sets (N).
    var total: Int
    /// How many sets are already logged (0...total).
    var filled: Int
    /// The set on screen now, if any.
    var current: Int?

    var body: some View {
        let count = max(total, 1)
        HStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { i in
                node(i)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("prototype-guided-set-stepper")
        .accessibilityLabel(label)
    }

    private var label: String {
        if let current {
            return "Set \(current + 1) of \(max(total, 1)). \(min(filled, total)) logged."
        }
        return "\(min(filled, total)) of \(max(total, 1)) sets logged."
    }

    private func node(_ i: Int) -> some View {
        let isCurrent = current == i
        let isFilled = i < filled
        return ZStack {
            Circle()
                .strokeBorder(isCurrent ? AppTheme.gold : AppTheme.quietStroke, lineWidth: isCurrent ? 2.5 : 1.5)
                .background(Circle().fill(fill(isFilled: isFilled, isCurrent: isCurrent)))
            if isFilled && !isCurrent {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
            } else {
                Text("\(i + 1)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(isCurrent || isFilled ? AppTheme.ink : AppTheme.quiet)
            }
        }
        .frame(width: 28, height: 28)
        .accessibilityLabel(nodeLabel(i, isFilled: isFilled, isCurrent: isCurrent))
    }

    private func fill(isFilled: Bool, isCurrent: Bool) -> Color {
        if isCurrent { return AppTheme.gold }
        if isFilled { return AppTheme.gold.opacity(0.85) }
        return AppTheme.quietFill
    }

    private func nodeLabel(_ i: Int, isFilled: Bool, isCurrent: Bool) -> String {
        if isCurrent { return "Set \(i + 1), current" }
        if isFilled { return "Set \(i + 1), logged" }
        return "Set \(i + 1), not logged"
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
