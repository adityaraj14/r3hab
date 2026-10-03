import SwiftUI

/// Debug choice on the guided set screen. The dial is the default.
enum PrototypeSetInputStyle: String, CaseIterable, Identifiable {
    case dial
    case ruler

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dial: return "Dial"
        case .ruler: return "Ruler"
        }
    }

    static let storageKey = "prototype.guided.setInput"
}

/// Rotary dial. Turn clockwise to go up. One detent is one step.
/// The gold mark at the top is the target. The knob shows the distance from the target.
struct PrototypeRotaryDial: View {
    var title: String
    var valueText: String
    var unit: String
    var deltaText: String
    var stepsFromTarget: Int
    var identifier: String
    /// Returns true when the value changed.
    var onStep: (Int) -> Bool

    static let degreesPerStep = 15.0
    private let ringWidth: CGFloat = 10

    @State private var lastAngle: Double?
    @State private var carry = 0.0

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                dial(size: size)
                    .frame(width: size, height: size)
                    .contentShape(Circle())
                    .gesture(drag(size: size))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
            .aspectRatio(1, contentMode: .fit)
            Text(deltaText)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(stepsFromTarget == 0 ? AppTheme.quiet : AppTheme.gold)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
        .accessibilityValue("\(valueText) \(unit), \(deltaText)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: _ = onStep(1)
            case .decrement: _ = onStep(-1)
            @unknown default: break
            }
        }
    }

    private func dial(size: CGFloat) -> some View {
        let fraction = min(abs(Double(stepsFromTarget)) * Self.degreesPerStep / 360, 0.999)
        // Ticks and the target mark sit outside the ring. The knob sits on the ring.
        let ringInset = ringWidth / 2 + 18
        return ZStack {
            ForEach(0..<24, id: \.self) { index in
                Capsule()
                    .fill(AppTheme.quietStroke)
                    .frame(width: 2, height: 6)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .rotationEffect(.degrees(Double(index) * Self.degreesPerStep))
            }
            Circle()
                .stroke(AppTheme.quietFill, lineWidth: ringWidth)
                .padding(ringInset)
            Circle()
                .trim(
                    from: stepsFromTarget >= 0 ? 0 : 1 - fraction,
                    to: stepsFromTarget >= 0 ? fraction : 1
                )
                .stroke(AppTheme.gold.opacity(0.75), style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(ringInset)
            // Target mark, above the knob so it stays visible.
            Capsule()
                .fill(AppTheme.gold)
                .frame(width: 5, height: 11)
                .frame(maxHeight: .infinity, alignment: .top)
            // Knob.
            Circle()
                .fill(AppTheme.ivory)
                .frame(width: ringWidth + 12, height: ringWidth + 12)
                .overlay(Circle().strokeBorder(AppTheme.canvas, lineWidth: 2))
                .padding(.top, ringInset - (ringWidth + 12) / 2)
                .frame(maxHeight: .infinity, alignment: .top)
                .rotationEffect(.degrees(Double(stepsFromTarget) * Self.degreesPerStep))
            VStack(spacing: 0) {
                Text(valueText)
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(AppTheme.ivory)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.quiet)
            }
            .padding(.horizontal, ringInset + ringWidth)
        }
    }

    private func drag(size: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.location.x - size / 2
                let dy = value.location.y - size / 2
                // Near the center the angle jumps. Ignore it there.
                guard dx * dx + dy * dy > (size * 0.15) * (size * 0.15) else {
                    lastAngle = nil
                    return
                }
                let angle = atan2(dy, dx) * 180 / .pi
                if let lastAngle {
                    var change = angle - lastAngle
                    if change > 180 { change -= 360 }
                    if change < -180 { change += 360 }
                    carry += change
                    while carry >= Self.degreesPerStep {
                        carry -= Self.degreesPerStep
                        if onStep(1) { Haptics.tick() }
                    }
                    while carry <= -Self.degreesPerStep {
                        carry += Self.degreesPerStep
                        if onStep(-1) { Haptics.tick() }
                    }
                }
                lastAngle = angle
            }
            .onEnded { _ in
                lastAngle = nil
                carry = 0
            }
    }
}

/// Horizontal ruler. Swipe left to go up. It stops on each value.
/// The gold tick is the target. The center line is the value.
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

    @State private var scrolled: Int?

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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(0..<count, id: \.self) { position in
                            tick(position)
                                .frame(width: tickWidth, height: rulerHeight)
                                .id(position)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, max((proxy.size.width - tickWidth) / 2, 0), for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $scrolled, anchor: .center)
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
            }
            .frame(height: rulerHeight)
        }
        .padding(14)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.cardHairline, lineWidth: 1)
        )
        .onAppear { scrolled = index }
        .onChange(of: scrolled) { _, next in
            guard let next, next != index else { return }
            onSelect(next)
            Haptics.tick()
        }
        .onChange(of: index) { _, next in
            if scrolled != next { scrolled = next }
        }
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

    private func tick(_ position: Int) -> some View {
        let isTarget = position == targetIndex
        let isMajor = isMajor(position)
        return VStack(spacing: 4) {
            Capsule()
                .fill(isTarget ? AppTheme.gold : AppTheme.quietStroke)
                .frame(width: isTarget ? 4 : 2, height: isTarget ? 30 : (isMajor ? 22 : 12))
                .frame(height: 30, alignment: .top)
            if isTarget {
                Circle()
                    .fill(AppTheme.gold)
                    .frame(width: 6, height: 6)
            } else if isMajor {
                Text(label(position))
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
