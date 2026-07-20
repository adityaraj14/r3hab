import SwiftUI

struct PhaseChip: View {
    let phase: RehabPhase

    var body: some View {
        Text(phase.title)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(phaseColor.opacity(0.18), in: Capsule())
            .foregroundStyle(phaseColor)
            .accessibilityLabel("Phase \(phase.title)")
    }

    private var phaseColor: Color {
        switch phase {
        case .aFlareDeLoad: return .red
        case .bIsometrics: return .orange
        case .cHeavySlowResistance: return .green
        case .dEnergyStorage: return .blue
        case .eReturnToSport: return .purple
        }
    }
}

#Preview {
    PhaseChip(phase: .aFlareDeLoad)
}
