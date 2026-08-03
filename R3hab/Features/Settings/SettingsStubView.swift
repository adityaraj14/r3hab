import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Settings: phase, thresholds, reminders, export/import, clear-all (PR-12/13/14).
struct SettingsStubView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query private var settingsList: [AppSettings]
    @Query private var checkIns: [DailyCheckIn]
    @Query private var sessions: [TrainingSession]

    @State private var exportURL: URL?
    @State private var showShare = false
    @State private var showImporter = false
    @State private var importMode: ImportMode = .replace
    @State private var showImportMode = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var isBusy = false
    @State private var showClearConfirm = false
    @State private var showClearSecondConfirm = false

    private var settings: AppSettings? { settingsList.first }
    private var totalLogs: Int { checkIns.count + sessions.count }

    var body: some View {
        List {
            if let settings {
                Section("Current phase") {
                    Picker("Phase", selection: phaseBinding(settings)) {
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
                        value: intBinding(settings, keyPath: \.phaseAStableDaysRequired),
                        in: 2...7
                    )
                    Stepper(
                        "Max AM pain for “stable”: \(settings.phaseAPainThreshold)",
                        value: intBinding(settings, keyPath: \.phaseAPainThreshold),
                        in: 0...5
                    )
                    Stepper(
                        "Near-normal steps: \(settings.stepNearNormalMin)",
                        value: intBinding(settings, keyPath: \.stepNearNormalMin),
                        in: 3000...15000,
                        step: 500
                    )
                }

                Section("Reminders") {
                    Toggle("Enable local reminders", isOn: notificationsBinding(settings))
                    DatePicker(
                        "Morning check-in",
                        selection: reminderTimeBinding(settings, isAM: true),
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "Evening check-in",
                        selection: reminderTimeBinding(settings, isAM: false),
                        displayedComponents: .hourAndMinute
                    )
                    LabeledContent("Stretch") {
                        Text(NotificationScheduler.stretchReminderTimesLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    Text("Check-in times are adjustable. Stretch reminders fire three times daily from 8:00 AM to 7:00 PM (evenly spaced). Also reminds for overdue 24h pending. Works offline.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Section("Backup") {
                LabeledContent("Check-ins", value: "\(checkIns.count)")
                LabeledContent("Sessions", value: "\(sessions.count)")

                Button {
                    exportBackup()
                } label: {
                    Label("Export JSON backup", systemImage: "square.and.arrow.up")
                }
                .disabled(isBusy)

                Button {
                    showImportMode = true
                } label: {
                    Label("Import JSON backup…", systemImage: "square.and.arrow.down")
                }
                .disabled(isBusy)
            }

            Section {
                Button("Clear all log entries", role: .destructive) {
                    showClearConfirm = true
                }
                .disabled(isBusy || totalLogs == 0)
            } header: {
                Text("Data")
            } footer: {
                Text("Deletes every daily check-in and training session. Settings (phase, thresholds, reminders) are kept. Export a backup first if you might need the data.")
            }

            Section("Protocol") {
                NavigationLink {
                    PhaseGuideView()
                } label: {
                    Label("Phase guide", systemImage: "list.bullet.clipboard")
                }
                LabeledContent("Revision", value: PhaseGuideCopy.protocolRevision)
            }

            Section {
                LabeledContent("App", value: "R3hab")
                LabeledContent("Data", value: "SwiftData (on-device)")
                LabeledContent("Bundle", value: "com.devrising.r3hab")
            }

            Section("Disclaimer") {
                Text("R3hab supports self-managed rehab logging. It is not a medical device and does not replace professional care.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(PhaseGuideCopy.redFlags)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            #if DEBUG
            Section("Debug") {
                Button("Seed sample week") {
                    seedSampleWeek()
                }
                Button("Reset onboarding flag") {
                    settings?.hasCompletedOnboarding = false
                    try? modelContext.save()
                    presentAlert("Onboarding", "Flag cleared — relaunch or kill app to see onboarding again if gated only on launch. Or toggle from Root next open.")
                }
            }
            #endif
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            _ = try? AppBootstrap.ensureSettings(context: modelContext)
        }
        .confirmationDialog("Import mode", isPresented: $showImportMode, titleVisibility: .visible) {
            Button("Replace all data", role: .destructive) {
                importMode = .replace
                showImporter = true
            }
            Button("Merge with existing") {
                importMode = .merge
                showImporter = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Replace wipes current check-ins and sessions first. Merge updates matching days/IDs and keeps the rest.")
        }
        .confirmationDialog(
            "Clear all log entries?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear \(totalLogs) entries", role: .destructive) {
                showClearSecondConfirm = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(checkIns.count) check-ins and \(sessions.count) sessions. Settings stay. Consider exporting a backup first.")
        }
        .confirmationDialog(
            "Really delete everything?",
            isPresented: $showClearSecondConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete all logs", role: .destructive) {
                clearAllLogs()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone without a backup file.")
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importFile(url: url)
            case .failure(let error):
                presentAlert("Import failed", error.localizedDescription)
            }
        }
        .sheet(isPresented: $showShare) {
            if let exportURL {
                ShareSheet(items: [exportURL])
                    .preferredColorScheme(.dark)
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func phaseBinding(_ settings: AppSettings) -> Binding<RehabPhase> {
        Binding(
            get: { settings.currentPhase },
            set: { newValue in
                settings.currentPhase = newValue
                try? modelContext.save()
            }
        )
    }

    private func intBinding(_ settings: AppSettings, keyPath: ReferenceWritableKeyPath<AppSettings, Int>) -> Binding<Int> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: {
                settings[keyPath: keyPath] = $0
                try? modelContext.save()
            }
        )
    }

    private func notificationsBinding(_ settings: AppSettings) -> Binding<Bool> {
        Binding(
            get: { settings.notificationsEnabled },
            set: { newValue in
                settings.notificationsEnabled = newValue
                try? modelContext.save()
                Task {
                    if newValue {
                        let granted = await NotificationScheduler.requestAuthorization()
                        await MainActor.run {
                            settings.notificationsEnabled = granted
                            try? modelContext.save()
                            if !granted {
                                presentAlert(
                                    "Notifications off",
                                    "Permission denied. You can enable them later in iOS Settings → R3hab."
                                )
                            }
                        }
                    }
                    await LogStore.reconcileNotifications(settings: settings, sessions: sessions)
                    await MainActor.run { router.requestNotificationSync() }
                }
            }
        )
    }

    private func reminderTimeBinding(_ settings: AppSettings, isAM: Bool) -> Binding<Date> {
        Binding(
            get: {
                var comps = DateComponents()
                comps.hour = isAM ? settings.amReminderHour : settings.pmReminderHour
                comps.minute = isAM ? settings.amReminderMinute : settings.pmReminderMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                let hour = comps.hour ?? (isAM ? 8 : 18)
                let minute = comps.minute ?? (isAM ? 0 : 30)
                if isAM {
                    settings.amReminderHour = hour
                    settings.amReminderMinute = minute
                } else {
                    settings.pmReminderHour = hour
                    settings.pmReminderMinute = minute
                }
                try? modelContext.save()
                Task {
                    await LogStore.reconcileNotifications(settings: settings, sessions: sessions)
                }
            }
        )
    }

    private func exportBackup() {
        isBusy = true
        defer { isBusy = false }
        do {
            let data = try ExportImportService.exportBackup(context: modelContext)
            let name = "R3hab-backup-\(Date().formatted(.iso8601.year().month().day())).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            exportURL = url
            showShare = true
        } catch {
            presentAlert("Export failed", error.localizedDescription)
        }
    }

    private func importFile(url: URL) {
        isBusy = true
        defer { isBusy = false }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            try ExportImportService.importBackup(data: data, mode: importMode, context: modelContext)
            let dailyN = (try? modelContext.fetchCount(FetchDescriptor<DailyCheckIn>())) ?? checkIns.count
            let sessN = (try? modelContext.fetchCount(FetchDescriptor<TrainingSession>())) ?? sessions.count
            if let settings {
                Task {
                    let latest = (try? modelContext.fetch(FetchDescriptor<TrainingSession>())) ?? sessions
                    await LogStore.reconcileNotifications(settings: settings, sessions: latest)
                }
            }
            presentAlert(
                "Import complete",
                "Mode: \(importMode.title). Check-ins: \(dailyN), sessions: \(sessN)."
            )
            router.requestNotificationSync()
        } catch {
            presentAlert("Import failed", error.localizedDescription)
        }
    }

    private func clearAllLogs() {
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try LogStore.clearAllLogs(context: modelContext)
            Haptics.warning()
            presentAlert(
                "Logs cleared",
                "Removed \(result.daily) check-ins and \(result.sessions) sessions. Settings kept."
            )
            router.requestNotificationSync()
        } catch {
            presentAlert("Clear failed", error.localizedDescription)
        }
    }

    private func presentAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    #if DEBUG
    private func seedSampleWeek() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let phase = settings?.currentPhase ?? .aFlareDeLoad
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = DailyCheckIn.dayKey(for: day)
            let existing = try? modelContext.fetch(
                FetchDescriptor<DailyCheckIn>(predicate: #Predicate { $0.dayKey == key })
            )
            if existing?.isEmpty == false { continue }
            let row = DailyCheckIn(date: day, phase: phase)
            row.restingPainAM = [2, 1, 2, 3, 1, 2, 2][offset]
            row.morningStiffness = [3, 2, 2, 3, 1, 2, 2][offset]
            row.dailyPainPM = [2, 2, 1, 3, 2, 2, 1][offset]
            row.lowerBackPainAM = [3, 2, 3, 4, 2, 3, 2][offset]
            row.lowerBackPainPM = [2, 3, 2, 3, 2, 2, 1][offset]
            row.steps = [4500, 6200, 7100, 3800, 8000, 5500, 6400][offset]
            modelContext.insert(row)
        }
        if sessions.isEmpty {
            let s = TrainingSession(
                date: today,
                phase: phase,
                sessionType: .isometrics,
                whatIDid: "Leg extension 3×1 @ 20 kg 30s hold",
                painDuring: 2,
                painAfter: 1,
                sets: 3,
                reps: 1,
                loadKg: 20,
                holdSeconds: 30
            )
            modelContext.insert(s)
        }
        try? modelContext.save()
        presentAlert("Seeded", "Sample daily rows for the past week (skipped existing day keys).")
        router.requestNotificationSync()
    }
    #endif
}

/// UIKit share sheet wrapper for exporting the JSON file.
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        SettingsStubView()
    }
    .environment(AppRouter())
    .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
    .preferredColorScheme(.dark)
}
