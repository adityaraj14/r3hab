import SwiftUI
import SwiftData

/// Phase guide for the selected injury (knee or QL strain).
struct PhaseGuideView: View {
    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }

    private var track: RehabTrackID {
        settings?.protocolTrack ?? .knee
    }

    private var template: RehabTemplate {
        RehabTemplate.template(for: track)
    }

    private var primaryLift: String {
        settings?.primaryLoad.title ?? PrimaryLoadCatalog.defaultSelectable(for: track).title
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(template.name)
                        .font(.headline)
                    Text(template.shortDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(template.objective(for: settings?.primaryLoad ?? PrimaryLoadCatalog.defaultSelectable(for: track)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                ForEach(RehabPhase.allCases) { phase in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phase.title)
                            .font(.subheadline.weight(.semibold))
                        Text(PhaseGuideCopy.summary(for: phase, primaryLift: primaryLift, track: track))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text(template.name)
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
