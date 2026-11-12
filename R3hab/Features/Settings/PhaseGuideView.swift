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

                ForEach(RehabPhase.planCases) { phase in
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

            Section("Rules") {
                Text("Pain up to 3 out of 10 during the exercise is fine if it is back to baseline by the next morning. If it is not, drop the load for one session.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Each week, test pain with a single-leg decline squat and rate it 0 to 10. The aim is a downward trend.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(TwelveWeekPlan.holdOffRunningAndJumping)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(TwelveWeekPlan.spanishSquatSkipNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Warning signs") {
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
