import SwiftUI
import SwiftData
import UIKit
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
    @State private var healthStatus: AppleHealthStatus = .checking
    @State private var showHealthExplainer = false
    #if DEBUG
    @State private var logPrototype: SessionLogPrototypeKind?
    #endif

    private var settings: AppSettings? { settingsList.first }
    private var totalLogs: Int { checkIns.count + sessions.count }
    private var debugFooter: String {
        #if DEBUG
        return "Open onboarding again does not remove records. The prototypes open the guided, live, and quick record forms. The standard form stays the default. This control is temporary."
        #else
        return "Open onboarding again does not remove records. This control is temporary."
        #endif
    }

    var body: some View {
        List {
            if let settings {
                Section("Phase") {
                    Picker("Phase", selection: phaseBinding(settings)) {
                        ForEach(RehabPhase.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                    Text(PhaseGuideCopy.summary(
                        for: settings.currentPhase,
                        primaryLift: settings.primaryLoad.title,
                        injuryID: settings.selectedInjuryID
                    ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(InjuryCatalog.isQL(settings.selectedInjuryID) ? "What you record" : "Primary exercise") {
                    Picker("Primary exercise", selection: primaryLoadBinding(settings)) {
                        ForEach(PrimaryLoadCatalog.options(for: settings.selectedInjuryID)) { option in
                            Text(option.title).tag(option.id)
                        }
                    }
                    Text(settings.primaryLoad.subtitle)
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
                        "Maximum morning pain for a stable day: \(settings.phaseAPainThreshold)",
                        value: intBinding(settings, keyPath: \.phaseAPainThreshold),
                        in: 0...5
                    )
                    Stepper(
                        "Minimum steps: \(settings.stepNearNormalMin)",
                        value: intBinding(settings, keyPath: \.stepNearNormalMin),
                        in: 3000...15000,
                        step: 500
                    )
                }

                Section("Reminders") {
                    Toggle("Enable reminders", isOn: notificationsBinding(settings))
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
                    Text("You can change the check-in times. R3hab also sends a reminder for an open 24-hour response. R3hab works offline.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Section {
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.title3)
                        .foregroundStyle(AppleHealthStyle.heart)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Health")
                        Text(healthStatus.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    switch healthStatus {
                    case .notConnected:
                        Button("Connect") { showHealthExplainer = true }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    case .connected:
                        Button("Change access") { openAppSettings() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    case .checking, .unavailable:
                        EmptyView()
                    }
                }
                .accessibilityIdentifier("settingsAppleHealthRow")
            } footer: {
                Text("R3hab reads only steps from Apple Health. R3hab never writes to Apple Health. To change access, open Apple Health. Select Sharing. Select Apps. Select R3hab.")
            }

            Section("Backup") {
                LabeledContent("Check-ins", value: "\(checkIns.count)")
                LabeledContent("Sessions", value: "\(sessions.count)")

                Button {
                    exportBackup()
                } label: {
                    Label("Export a JSON backup", systemImage: "square.and.arrow.up")
                }
                .disabled(isBusy)

                Button {
                    showImportMode = true
                } label: {
                    Label("Import a JSON backup", systemImage: "square.and.arrow.down")
                }
                .disabled(isBusy)
            }

            Section {
                Button("Remove all records", role: .destructive) {
                    showClearConfirm = true
                }
                .disabled(isBusy || totalLogs == 0)
            } header: {
                Text("Data")
            } footer: {
                Text("This removes every daily check-in and every session. R3hab keeps the settings. Export a backup first if you need the data.")
            }

            Section("Protocol") {
                if let settings {
                    Picker("Injury", selection: injuryBinding(settings)) {
                        ForEach(InjuryCatalog.all) { injury in
                            Text(injury.title).tag(injury.id)
                        }
                    }
                }
                NavigationLink {
                    PhaseGuideView()
                } label: {
                    Label("Phase guide", systemImage: "list.bullet.clipboard")
                }
                LabeledContent("Revision", value: PhaseGuideCopy.protocolRevision)
            }

            Section {
                Text(BrandCopy.settingsBlurb)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ForEach(BrandCopy.benefits) { benefit in
                    BrandCardRow(card: benefit)
                        .padding(.vertical, 2)
                }
            } header: {
                Text(BrandCopy.settingsSectionTitle)
            } footer: {
                Text(BrandCopy.tenetLine)
            }

            Section("Disclaimer") {
                Text(PhaseGuideCopy.medicalDisclaimer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(PhaseGuideCopy.redFlags)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // TEMPORARY: one Debug section. "Simulate onboarding" ships in TestFlight
            // until onboarding UX sign-off; "Seed sample week" is DEBUG-only.
            // Remove the whole section before App Store / public release.
            Section {
                Button("Open onboarding again") {
                    simulateOnboarding()
                }
                #if DEBUG
                Button("Add a sample week") {
                    seedSampleWeek()
                }
                ForEach(SessionLogPrototypeKind.allCases) { kind in
                    Button(kind.settingsTitle) { logPrototype = kind }
                        .accessibilityIdentifier(SessionPrototypeAccessibility.open(kind))
                }
                #endif
            } header: {
                Text("Debug")
            } footer: {
                Text(debugFooter)
            }
        }
        .appListCanvas()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        #if DEBUG
        .sessionPrototypeSheet(selection: $logPrototype, date: Date())
        #endif
        .task {
            _ = try? AppBootstrap.ensureSettings(context: modelContext)
            await refreshHealthStatus()
        }
        .sheet(isPresented: $showHealthExplainer, onDismiss: {
            Task { await refreshHealthStatus() }
        }) {
            AppleHealthPermissionView()
        }
        .confirmationDialog("Select the import mode", isPresented: $showImportMode, titleVisibility: .visible) {
            Button("Replace all records", role: .destructive) {
                importMode = .replace
                showImporter = true
            }
            Button("Merge with current records") {
                importMode = .merge
                showImporter = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Replace removes the current check-ins and sessions first. Merge updates matching days and sessions and keeps the other records.")
        }
        .confirmationDialog(
            "Remove all records?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove \(totalLogs) records", role: .destructive) {
                showClearSecondConfirm = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(checkIns.count) check-ins and \(sessions.count) sessions. R3hab keeps the settings. Export a backup first.")
        }
        .confirmationDialog(
            "Remove all records?",
            isPresented: $showClearSecondConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove all records", role: .destructive) {
                clearAllLogs()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You cannot restore this data without a backup file.")
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

    private func injuryBinding(_ settings: AppSettings) -> Binding<String> {
        Binding(
            get: { InjuryCatalog.normalizedID(settings.selectedInjuryID) },
            set: { newValue in
                let injuryID = InjuryCatalog.normalizedID(newValue)
                settings.selectedInjuryID = injuryID
                settings.primaryLoadID = PrimaryLoadCatalog.normalizedID(
                    settings.primaryLoadID,
                    injuryID: injuryID
                )
                try? modelContext.save()
            }
        )
    }

    private func primaryLoadBinding(_ settings: AppSettings) -> Binding<String> {
        Binding(
            get: {
                PrimaryLoadCatalog.normalizedID(settings.primaryLoadID, injuryID: settings.selectedInjuryID)
            },
            set: { newValue in
                settings.primaryLoadID = PrimaryLoadCatalog.normalizedID(
                    newValue,
                    injuryID: settings.selectedInjuryID
                )
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
                Task {
                    await applyNotificationsEnabled(newValue, settings: settings)
                }
            }
        )
    }

    @MainActor
    private func applyNotificationsEnabled(_ enabled: Bool, settings: AppSettings) async {
        if enabled {
            let granted = await NotificationScheduler.ensureAuthorizedIfNeeded()
            settings.notificationsEnabled = granted
            try? modelContext.save()
            if !granted {
                presentAlert(
                    "Reminders are off",
                    "R3hab cannot send reminders. Open Settings. Select R3hab. Enable reminders."
                )
            }
        } else {
            settings.notificationsEnabled = false
            try? modelContext.save()
        }
        let snapshot = LogStore.notificationSnapshot(settings: settings, sessions: sessions)
        await LogStore.reconcileNotifications(snapshot)
        router.requestNotificationSync()
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
                let snapshot = LogStore.notificationSnapshot(settings: settings, sessions: sessions)
                Task {
                    await LogStore.reconcileNotifications(snapshot)
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
                let latest = (try? modelContext.fetch(FetchDescriptor<TrainingSession>())) ?? sessions
                let snapshot = LogStore.notificationSnapshot(settings: settings, sessions: latest)
                Task {
                    await LogStore.reconcileNotifications(snapshot)
                }
            }
            presentAlert(
                "Import complete",
                "Mode: \(importMode.title). Check-ins: \(dailyN). Sessions: \(sessN)."
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
                "Records removed",
                "R3hab removed \(result.daily) check-ins and \(result.sessions) sessions. R3hab kept the settings."
            )
            router.requestNotificationSync()
        } catch {
            presentAlert("Remove failed", error.localizedDescription)
        }
    }

    @MainActor
    private func refreshHealthStatus() async {
        guard HealthKitSteps.isAvailable else {
            healthStatus = .unavailable
            return
        }
        healthStatus = await HealthKitSteps.needsAuthorizationPrompt() ? .notConnected : .connected
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func presentAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    /// TEMPORARY: re-open onboarding without wiping the diary. Remove before App Store.
    private func simulateOnboarding() {
        guard let settings else { return }
        OnboardingReset.reopenGate(on: settings)
        try? modelContext.save()
        router.requestOnboardingReplay()
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
            row.dailyPainPM = [2, 2, 1, 3, 2, 2, 1][offset]
            row.steps = [4500, 6200, 7100, 3800, 8000, 5500, 6400][offset]
            modelContext.insert(row)
        }
        if sessions.isEmpty {
            let s = TrainingSession(
                date: today,
                phase: phase,
                sessionType: .isometrics,
                whatIDid: "Seated leg extension 3×1 @ 15 lb, 30 s hold",
                painDuring: 2,
                painAfter: 1,
                sets: 3,
                reps: 1,
                loadLbs: 15,
                holdSeconds: 30
            )
            modelContext.insert(s)
        }
        try? modelContext.save()
        presentAlert("Sample week added", "R3hab added sample rows for the past week. Existing days stay.")
        router.requestNotificationSync()
    }
    #endif
}

/// Apple Health row state. HealthKit never reveals whether read access was
/// granted, so "connected" means the user has answered the Health prompt.
enum AppleHealthStatus {
    case checking
    case connected
    case notConnected
    case unavailable

    var subtitle: String {
        switch self {
        case .checking: return "R3hab checks Apple Health."
        case .connected: return "Connected. R3hab reads steps."
        case .notConnected: return "Not connected"
        case .unavailable: return "Not available on this device"
        }
    }
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
