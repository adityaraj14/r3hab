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

struct PrototypeProgressDots: View {
    var count: Int
    var index: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { step in
                Capsule()
                    .fill(fill(for: step))
                    .frame(width: step == index ? 18 : 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(SessionPrototypeAccessibility.progress)
        .accessibilityLabel("Step \(index + 1) of \(count)")
    }

    private func fill(for step: Int) -> Color {
        if step == index { return AppTheme.gold }
        if step < index { return Color.white.opacity(0.85) }
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
