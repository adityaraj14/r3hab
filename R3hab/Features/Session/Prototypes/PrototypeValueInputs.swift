import SwiftUI

/// Horizontal ruler. Swipe left to go up. It stops on each value.
/// The gold tick is the target. The center line is the value.
/// The ruler follows the finger. After the finger lifts, a flick adds at most
/// `SessionPrototypePlan.rulerMaxFlickSteps` steps, so a short flick moves 1 or 2 values.
struct PrototypeRulerWheel: View {
    var title: String
    var valueText: String
    var unit: String
    var deltaText: String
    var onTarget: Bool
    var count: Int
    var index: Int
    var targetIndex: Int
    /// Long tick with a number below it.
    var isMajor: (Int) -> Bool
    var label: (Int) -> String
    var identifier: String
    var onSelect: (Int) -> Void

    private let tickWidth: CGFloat = 14
    private let rulerHeight: CGFloat = 62

    /// Ruler position when the drag started. Nil when no drag.
    @State private var dragStart: Double?
    /// Ruler position under the finger. Nil when no drag.
    @State private var livePosition: Double?

    private var position: Double { livePosition ?? Double(index) }

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.quiet)
                Spacer()
                Text(deltaText)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(onTarget ? AppTheme.quiet : AppTheme.gold)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(valueText)
                    .font(.system(size: 52, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(AppTheme.ivory)
                Text(unit)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.quiet)
            }
            GeometryReader { proxy in
                let width = proxy.size.width
                HStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { tickIndex in
                        tick(tickIndex)
                            .frame(width: tickWidth, height: rulerHeight)
                    }
                }
                .fixedSize()
                .offset(x: width / 2 - (CGFloat(position) + 0.5) * tickWidth)
                .frame(width: width, height: rulerHeight, alignment: .leading)
                .clipped()
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(AppTheme.ivory)
                        .frame(width: 3, height: 36)
                        .allowsHitTesting(false)
                }
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.18),
                            .init(color: .black, location: 0.82),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .contentShape(Rectangle())
                .gesture(drag)
            }
            .frame(height: rulerHeight)
        }
        .padding(14)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.cardHairline, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
        .accessibilityValue("\(valueText) \(unit), \(deltaText)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment where index + 1 < count: onSelect(index + 1)
            case .decrement where index > 0: onSelect(index - 1)
            default: break
            }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let start = dragStart ?? Double(index)
                dragStart = start
                let next = SessionPrototypePlan.rulerPosition(
                    start: start,
                    dragPoints: value.translation.width,
                    tickWidth: tickWidth,
                    count: count
                )
                livePosition = next
                select(Int(next.rounded()))
            }
            .onEnded { value in
                let final = SessionPrototypePlan.rulerFinalIndex(
                    position: livePosition ?? Double(index),
                    momentumPoints: value.predictedEndTranslation.width - value.translation.width,
                    tickWidth: tickWidth,
                    count: count
                )
                select(final)
                dragStart = nil
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    livePosition = nil
                }
            }
    }

    /// One haptic tick for each value change.
    private func select(_ next: Int) {
        guard next != index else { return }
        onSelect(next)
        Haptics.tick()
    }

    private func tick(_ tickIndex: Int) -> some View {
        let isTarget = tickIndex == targetIndex
        let major = isMajor(tickIndex)
        return VStack(spacing: 4) {
            Capsule()
                .fill(isTarget ? AppTheme.gold : AppTheme.quietStroke)
                .frame(width: isTarget ? 4 : 2, height: isTarget ? 30 : (major ? 22 : 12))
                .frame(height: 30, alignment: .top)
            if isTarget {
                Circle()
                    .fill(AppTheme.gold)
                    .frame(width: 6, height: 6)
            } else if major {
                Text(label(tickIndex))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.quiet)
                    .fixedSize()
            }
            Spacer(minLength: 0)
        }
    }
}

/// Small − value + control for warm-up steps.
struct PrototypeMiniStepper: View {
    var title: String
    var value: String
    var identifier: String
    var onMinus: () -> Void
    var onPlus: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
            HStack(spacing: 6) {
                button("minus", name: "decrease", action: onMinus)
                Text(value)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppTheme.ivory)
                    .frame(minWidth: 48)
                    .accessibilityIdentifier("\(identifier)-value")
                button("plus", name: "increase", action: onPlus)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func button(_ symbol: String, name: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tick()
        } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ivory)
                .frame(width: 38, height: 38)
                .background(AppTheme.quietFill, in: Circle())
                .overlay(Circle().strokeBorder(AppTheme.quietStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(identifier)-\(symbol)")
        .accessibilityLabel("\(title) \(name)")
    }
}
