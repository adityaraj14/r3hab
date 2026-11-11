import SwiftUI

/// Quiet phase chip: white text, faint fill, one small phase-colored dot.
struct PhaseChip: View {
    let phase: RehabPhase

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(phaseColor)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(phase.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.quietFill, in: Capsule())
        .overlay(Capsule().strokeBorder(AppTheme.quietStroke, lineWidth: 1))
        .accessibilityLabel("Phase \(phase.title)")
    }

    private var phaseColor: Color {
        switch phase {
        case .aFlareDeLoad: return .red
        case .bIsometrics, .calmTendon: return .orange
        case .cHeavySlowResistance, .heavySlow: return .green
        case .heavier: return .mint
        case .springiness: return .purple
        }
    }
}

#Preview {
    PhaseChip(phase: .aFlareDeLoad)
        .padding()
        .background(AppTheme.canvas)
        .preferredColorScheme(.dark)
}
