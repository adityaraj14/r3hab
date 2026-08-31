import SwiftUI
import SwiftData

/// Patellar tendinopathy phase guide (A–E).
struct PhaseGuideView: View {
    @Query private var settingsList: [AppSettings]

    private var primaryLift: String {
        settingsList.first?.primaryLoad.title ?? PrimaryLoadCatalog.defaultSelectable.title
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(RehabTemplate.knee.name)
                        .font(.headline)
                    Text(RehabTemplate.knee.shortDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(RehabTemplate.knee.objective(for: settingsList.first?.primaryLoad ?? PrimaryLoadCatalog.defaultSelectable))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                ForEach(RehabPhase.allCases) { phase in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phase.title)
                            .font(.subheadline.weight(.semibold))
                        Text(PhaseGuideCopy.summary(for: phase, primaryLift: primaryLift))
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
    .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
    .preferredColorScheme(.dark)
}
