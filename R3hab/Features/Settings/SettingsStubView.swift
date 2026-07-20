import SwiftUI
import SwiftData

/// Settings: phase + thresholds (export/import still PR-12).
struct SettingsStubView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [AppSettings]

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        List {
            if let settings {
                Section("Current phase") {
                    Picker("Phase", selection: Binding(
                        get: { settings.currentPhase },
                        set: { newValue in
                            settings.currentPhase = newValue
                            settings.phaseChangedAt = Date()
                            try? modelContext.save()
                        }
                    )) {
                        ForEach(RehabPhase.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                    Text(PhaseGuideCopy.summary(for: settings.currentPhase))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Phase A thresholds") {
                    Stepper(
                        "Stable days required: \(settings.phaseAStableDaysRequired)",
                        value: Binding(
                            get: { settings.phaseAStableDaysRequired },
                            set: {
                                settings.phaseAStableDaysRequired = $0
                                try? modelContext.save()
                            }
                        ),
                        in: 2...7
                    )
                    Stepper(
                        "Max AM pain for “stable”: \(settings.phaseAPainThreshold)",
                        value: Binding(
                            get: { settings.phaseAPainThreshold },
                            set: {
                                settings.phaseAPainThreshold = $0
                                try? modelContext.save()
                            }
                        ),
                        in: 0...5
                    )
                    Stepper(
                        "Near-normal steps: \(settings.stepNearNormalMin)",
                        value: Binding(
                            get: { settings.stepNearNormalMin },
                            set: {
                                settings.stepNearNormalMin = $0
                                try? modelContext.save()
                            }
                        ),
                        in: 3000...15000,
                        step: 500
                    )
                }
            }

            Section {
                LabeledContent("App", value: "R3hab")
                LabeledContent("Protocol", value: PhaseGuideCopy.protocolRevision)
                LabeledContent("Data", value: "SwiftData (on-device)")
            }

            Section {
                Text("JSON export / import lands next (PR-12).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Disclaimer") {
                Text("R3hab supports self-managed rehab logging. It is not a medical device and does not replace professional care.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(PhaseGuideCopy.redFlags)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            _ = try? AppBootstrap.ensureSettings(context: modelContext)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsStubView()
    }
    .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
    .preferredColorScheme(.dark)
}
