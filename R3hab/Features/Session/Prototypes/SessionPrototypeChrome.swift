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

    var body: some View {
        Text(value.map(String.init) ?? "—")
            .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(value.map { PrototypePainColor.color(for: $0) } ?? AppTheme.quiet)
            .accessibilityHidden(true)
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

struct PrototypeDoseReadout: View {
    var reps: Int
    var loadLbs: Double?
    var identifier: String

    var body: some View {
        VStack(spacing: 0) {
            if let loadLbs {
                Text(LoadCopy.formatted(loadLbs))
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text("lbs  ×  \(reps)")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.quiet)
            } else {
                Text("\(reps)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                Text("reps")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.quiet)
            }
        }
        .foregroundStyle(AppTheme.ivory)
        .monospacedDigit()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(spoken)
    }

    private var spoken: String {
        if let loadLbs {
            return "\(LoadCopy.labeled(loadLbs)) times \(reps) reps"
        }
        return "\(reps) reps"
    }
}

struct PrototypeAdjustRow: View {
    var title: String
    var value: String
    var minusIdentifier: String
    var plusIdentifier: String
    var onMinus: () -> Void
    var onPlus: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
            HStack(spacing: 14) {
                stepButton("−", identifier: minusIdentifier, name: "decrease", action: onMinus)
                Text(value)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppTheme.ivory)
                    .frame(minWidth: 56)
                stepButton("+", identifier: plusIdentifier, name: "increase", action: onPlus)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stepButton(
        _ glyph: String,
        identifier: String,
        name: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.ivory)
                .frame(width: 56, height: 56)
                .background(AppTheme.quietFill, in: Circle())
                .overlay(Circle().strokeBorder(AppTheme.quietStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel("\(title) \(name)")
    }
}

struct PrototypeValueChip: View {
    var title: String
    var selected: Bool
    var identifier: String
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(selected ? AppTheme.ink : AppTheme.ivory)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? AppTheme.gold : AppTheme.quietFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(selected ? AppTheme.gold : AppTheme.quietStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

struct PrototypeSetBeads: View {
    var count: Int
    var completed: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index < completed ? AppTheme.gold : AppTheme.quietFill)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(AppTheme.quietStroke, lineWidth: index < completed ? 0 : 1))
            }
        }
        .accessibilityLabel("\(completed) of \(count) sets logged")
    }
}
