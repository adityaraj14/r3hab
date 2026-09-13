import SwiftUI
import SwiftData

/// Phase guide for the knee protocol (jumper’s knee / patellar tendinopathy).
struct PhaseGuideView: View {
    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }

    private var primaryLoad: PrimaryLoadOption {
        settings?.primaryLoad ?? PrimaryLoadCatalog.defaultSelectable
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(InjuryCatalog.protocolName)
                        .font(.headline)
                    Text(InjuryCatalog.protocolDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(primaryLoad.homeObjective)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                ForEach(RehabPhase.allCases) { phase in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phase.title)
                            .font(.subheadline.weight(.semibold))
                        Text(PhaseGuideCopy.summary(for: phase, primaryLift: primaryLoad.title))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text(InjuryCatalog.protocolName)
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
        .appListCanvas()
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
