import SwiftUI

/// True black, white type, one electric lime pop. Color is a highlight —
/// the streak count, the chain, the next action — not a tint on every surface.
enum AppTheme {
    /// Volt. Next action, streak count, hard-chain beads. Matches AccentColor.
    static let gold = Color(red: 0.84, green: 1.0, blue: 0.18)
    /// Text on top of the lime fill.
    static let ink = Color(white: 0.05)
    static let canvas = Color.black
    /// One step up from black so a card is a shape, not a brown wash.
    static let surface = Color(white: 0.11)
    static let ivory = Color.white
    static let quiet = Color(white: 0.72)
    /// Rest-day bead. Neutral, so the only color on the chain is a hard day.
    static let rest = Color(white: 0.55)
    static let quietFill = Color.white.opacity(0.08)
    static let quietStroke = Color.white.opacity(0.18)
    static let cardHairline = Color.white.opacity(0.16)
}

/// Lime fill. The default next action.
/// Disabled is unmistakable: dim fill, dim text, no shadow of "half gold".
struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(isEnabled ? AppTheme.ink : Color.white.opacity(0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isEnabled ? AppTheme.gold : Color.white.opacity(0.06))
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Neutral secondary. White text on a faint white fill — reads as "available,
/// not the default", and is visibly different from disabled.
struct QuietActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
            .foregroundStyle(isEnabled ? Color.white : Color.white.opacity(0.3))
            .padding(.vertical, compact ? 8 : 14)
            .padding(.horizontal, compact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous)
                    .fill(isEnabled ? AppTheme.quietFill : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous)
                    .strokeBorder(isEnabled ? AppTheme.quietStroke : Color.clear, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryActionButtonStyle {
    static var primaryAction: PrimaryActionButtonStyle { PrimaryActionButtonStyle() }
}

extension ButtonStyle where Self == QuietActionButtonStyle {
    static var quietAction: QuietActionButtonStyle { QuietActionButtonStyle() }
    static var quietCompact: QuietActionButtonStyle { QuietActionButtonStyle(compact: true) }
}

extension View {
    /// Root-screen background: soft canvas behind scroll content.
    func appCanvas() -> some View {
        background(AppTheme.canvas.ignoresSafeArea())
    }

    /// List/Form variant: hides the system grouped background first.
    func appListCanvas() -> some View {
        scrollContentBackground(.hidden)
            .background(AppTheme.canvas.ignoresSafeArea())
    }

    /// Surface card with a warm hairline. Padding stays with the caller.
    func posterCard(radius: CGFloat = 16) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(AppTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(AppTheme.cardHairline, lineWidth: 1)
                }
        }
    }
}
