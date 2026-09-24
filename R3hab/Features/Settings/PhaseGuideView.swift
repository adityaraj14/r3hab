import SwiftUI
import SwiftData

/// Phase guide for the selected injury. QL copy is a logging stub.
struct PhaseGuideView: View {
    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }

    private var injury: InjuryDefinition {
        settings?.selectedInjury ?? InjuryCatalog.defaultSelectable
    }

    private var primaryLoad: PrimaryLoadOption {
        settings?.primaryLoad ?? PrimaryLoadCatalog.defaultSelectable
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(injury.protocolName)
                        .font(.headline)
                    Text(injury.protocolDescription)
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
                        Text(PhaseGuideCopy.summary(
                            for: phase,
                            primaryLift: primaryLoad.title,
                            injuryID: injury.id
                        ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text(injury.protocolName)
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
