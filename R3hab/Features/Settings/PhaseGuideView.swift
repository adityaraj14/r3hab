import SwiftUI

/// Dual-track protocol guide: knee tendon + low back / QL.
struct PhaseGuideView: View {
    var body: some View {
        List {
            Section {
                Text("Two active rehab templates. Log daily pain for both; train each track separately. Soft cut when next-day symptoms are worse.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

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
                Text("Template 1 · Knee")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(RehabTemplate.lowerBack.name)
                        .font(.headline)
                    Text(RehabTemplate.lowerBack.shortDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(BackProtocolCopy.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(BackProtocolCopy.program)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Template 2 · Low back")
            }

            Section("Red flags") {
                Text(PhaseGuideCopy.redFlags)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(BackProtocolCopy.redFlags)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Protocol revision", value: PhaseGuideCopy.protocolRevision)
            }
        }
        .navigationTitle("Rehab templates")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PhaseGuideView()
    }
    .preferredColorScheme(.dark)
}
