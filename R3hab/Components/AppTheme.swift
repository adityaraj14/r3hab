import SwiftUI

/// Near-black canvas, one bright gold reserved for the single next action,
/// and quiet white/warm-gray for everything else.
///
/// Rule of thumb: if a screen has more than one gold element, one of them is
/// wrong. Secondary buttons, chips, links, icons, and tab items use `quiet*`.
enum AppTheme {
    /// The one bright accent. Same value as the AccentColor asset.
    static let gold = Color(red: 0.91, green: 0.73, blue: 0.23)
    /// Text on top of a gold fill.
    static let ink = Color(red: 0.07, green: 0.06, blue: 0.04)
    /// One step off pure black so cards and text have a floor to sit on.
    static let canvas = Color(red: 0.055, green: 0.055, blue: 0.06)
    /// Card surface on the canvas.
    static let surface = Color(.secondarySystemBackground)
    /// Warm gray for secondary chrome (eyebrows, icons, chips) — quieter than
    /// `.secondary`, never competes with gold.
    static let quiet = Color(red: 0.66, green: 0.63, blue: 0.57)
    /// Subtle hairline / fill for quiet controls.
    static let quietFill = Color.white.opacity(0.08)
    static let quietStroke = Color.white.opacity(0.14)
}

/// Bright gold fill. Use once per screen for the default next action.
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
}
