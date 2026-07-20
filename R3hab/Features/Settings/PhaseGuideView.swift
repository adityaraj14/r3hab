import SwiftUI

/// Read-only condensed phase ladder + red flags (PR-12).
struct PhaseGuideView: View {
    var body: some View {
        List {
            Section {
                Text("Progressive loading with pain-guided decisions. One variable at a time. Soft cut when 24h is worse; hard drop if pain climbs or capacity collapses.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Phase ladder") {
                ForEach(RehabPhase.allCases) { phase in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(phase.title)
                            .font(.headline)
                        Text(PhaseGuideCopy.summary(for: phase))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Red flags") {
                Text(PhaseGuideCopy.redFlags)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Protocol revision", value: PhaseGuideCopy.protocolRevision)
            }
        }
        .navigationTitle("Phase guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PhaseGuideView()
    }
    .preferredColorScheme(.dark)
}
