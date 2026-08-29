import SwiftUI

/// Patellar tendinopathy phase guide (A–E).
struct PhaseGuideView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(RehabTemplate.knee.name)
                        .font(.headline)
                    Text(RehabTemplate.knee.shortDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(RehabTemplate.knee.objective80_20)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                ForEach(RehabPhase.allCases) { phase in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phase.title)
                            .font(.subheadline.weight(.semibold))
                        Text(PhaseGuideCopy.summary(for: phase))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Jumper's knee")
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
