import SwiftUI
import SwiftData

/// Create/edit one daily check-in (partial AM/PM save OK).
///
/// Holds only value state. The row is read into fields on appear and written
/// back with fetch-or-insert by dayKey on the current context, so a long
/// background between open and Save never touches a stale `DailyCheckIn`.
struct DailyCheckInEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]

    /// Calendar day to edit (start-of-day). Defaults to today.
    var targetDate: Date = Date()
    var focus: DailyCheckInFocus = .full

    @State private var restingPainAM: Int?
    @State private var dailyPainPM: Int?
    @State private var stepsText: String = ""
    @State private var phase: RehabPhase = .aFlareDeLoad
    @State private var notes: String = ""
    @State private var declineL: Int?
    @State private var declineR: Int?
    /// What the row held when the editor opened — drives titles and the nudge.
    @State private var hadRowOnLoad = false
    @State private var morningPainOnLoad: Int?
    @State private var eveningPainOnLoad: Int?
    @State private var errorMessage: String?
    @State private var didLoad = false
    @State private var isLoadingSteps = false
    @State private var stepsSourceNote: String?
    @State private var loadNudge: LoadNudge?
    @State private var showHealthExplainer = false
    /// User tapped "Not now" on the Apple Health explainer; stop auto-showing it.
    @AppStorage("appleHealthExplainerDeferred") private var healthExplainerDeferred = false

    private var calendar: Calendar { .current }
    private var showsMorning: Bool { focus != .evening }
    private var showsEvening: Bool { focus != .morning }

    var body: some View {
        Form {
            Section {
                Text(dayLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if showsMorning {
                    Picker("Phase", selection: $phase) {
                        ForEach(RehabPhase.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                }
            }

            if showsMorning {
                Section {
                    morningPainRuler
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    if focus == .full, restingPainAM != nil {
                        Button("Clear") { restingPainAM = nil }
                            .font(.footnote)
                            .accessibilityIdentifier("morning-pain-clear")
                    }
                } header: {
                    Text("Morning")
                } footer: {
                    Text("Record the resting knee pain before the day starts. Use 0 to 10. Record the evening pain and the steps separately.")
                }
            }

            if showsEvening {
                Section {
                    PainScoreControl(title: "Pain during daily activities", value: $dailyPainPM)

                    HStack {
                        TextField("Steps", text: $stepsText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.plain)
                            .accessibilityLabel("Steps")
                        if isLoadingSteps {
                            ProgressView()
                        } else if HealthKitSteps.isAvailable {
                            Button {
                                Task { await startHealthImport() }
                            } label: {
                                Label("Apple Health", systemImage: "heart.fill")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .accessibilityHint("Import step count from Apple Health")
                        }
                    }

                    if let stepsSourceNote {
                        Text(stepsSourceNote)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Evening")
                } footer: {
                    Text("Record the pain during the day's activities. Use 0 to 10. The steps show Phase A progress. You can import the steps from Apple Health. You can also edit the number.")
                }

                Section {
                    PainScoreControl(title: "Left", value: $declineL)
                    PainScoreControl(title: "Right", value: $declineR)
                } header: {
                    Text("Decline squat")
                } footer: {
                    Text(declineSquatFooter)
                }
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear(perform: loadIfNeeded)
        .loadNudgeAlert($loadNudge) {
            loadNudge = nil
            dismiss()
        }
        .task {
            guard showsEvening else { return }
            // Auto-fill steps from Health when empty (today or backdated day).
            guard stepsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            guard HealthKitSteps.isAvailable else { return }
            if await HealthKitSteps.needsAuthorizationPrompt() {
                // Explain Apple Health before the system prompt, once.
                if !healthExplainerDeferred { showHealthExplainer = true }
                return
            }
            await importStepsFromHealth(silentIfNoData: true)
        }
        .sheet(isPresented: $showHealthExplainer, onDismiss: {
            Task {
                if await HealthKitSteps.needsAuthorizationPrompt() {
                    healthExplainerDeferred = true
                }
            }
        }) {
            AppleHealthPermissionView {
                Task { await importStepsFromHealth(silentIfNoData: true) }
            }
        }
    }

    /// The day before `targetDate`, for the prefill and the comparison text.
    private var yesterdayMorningPain: Int? {
        MorningPain.yesterday(before: targetDate, checkIns: checkIns.map(\.snapshot), calendar: calendar)
    }

    /// The same swipe ruler as the working sets. A value that is not recorded
    /// (full check-in only) shows "—" until the first move or tap.
    private var morningPainRuler: some View {
        let yesterday = yesterdayMorningPain
        let shown = restingPainAM ?? MorningPain.prefill(yesterday: yesterday)
        return PrototypeRulerWheel(
            title: "Knee resting pain",
            valueText: restingPainAM.map(String.init) ?? "\u{2014}",
            unit: "of 10",
            deltaText: MorningPain.comparison(
                restingPainAM,
                yesterday: yesterday,
                isToday: calendar.isDateInToday(targetDate)
            ),
            onTarget: restingPainAM == nil || yesterday == nil || restingPainAM == yesterday,
            count: MorningPain.range.count,
            index: shown,
            targetIndex: yesterday ?? -1,
            isMajor: { _ in true },
            label: { "\($0)" },
            identifier: "morning-pain-ruler",
            tickWidth: 28,
            onSelect: { restingPainAM = $0 }
        )
        .onTapGesture {
            if restingPainAM == nil { restingPainAM = shown }
        }
    }

    private var navigationTitleText: String {
        switch focus {
        case .morning:
            return morningPainOnLoad != nil ? "Edit morning" : "Record morning"
        case .evening:
            return eveningPainOnLoad != nil ? "Edit evening" : "Record evening"
        case .full:
            return hadRowOnLoad ? "Edit check-in" : "New check-in"
        }
    }

    private var dayLabel: String {
        let d = calendar.startOfDay(for: targetDate)
        return d.formatted(date: .complete, time: .omitted)
    }

    private var declineSquatFooter: String {
        """
        This test is optional. Do a single-leg squat on a decline board. Record the knee pain from 0 to 10 for each side. Do this one to three times each week. Skip this test on a flare day. The morning pain and the evening pain are more important.
        """
    }

    /// Reads the day into value fields. The fetched model is not retained.
    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true

        if let settings = try? AppBootstrap.ensureSettings(context: modelContext) {
            phase = settings.currentPhase
        }

        guard let values = try? DailyCheckInStore.values(forDay: targetDate, context: modelContext, calendar: calendar) else {
            prefillMorningPainIfFocused()
            return
        }
        hadRowOnLoad = true
        morningPainOnLoad = values.restingPainAM
        eveningPainOnLoad = values.dailyPainPM
        restingPainAM = values.restingPainAM
        dailyPainPM = values.dailyPainPM
        stepsText = values.steps.map(String.init) ?? ""
        phase = values.phase
        notes = values.notes
        declineL = values.declineSquatL
        declineR = values.declineSquatR
        if values.steps != nil {
            stepsSourceNote = "Saved value — tap Apple Health to refresh."
        }
        prefillMorningPainIfFocused()
    }

    /// The morning editor opens with a value on the ruler: yesterday's morning pain, or 0.
    /// The full check-in does not, so an edit of other fields does not record a morning value.
    private func prefillMorningPainIfFocused() {
        guard focus == .morning, restingPainAM == nil else { return }
        restingPainAM = MorningPain.prefill(yesterday: yesterdayMorningPain)
    }

    /// Health button: explain first if the system prompt has not been shown yet.
    @MainActor
    private func startHealthImport() async {
        if await HealthKitSteps.needsAuthorizationPrompt() {
            showHealthExplainer = true
        } else {
            await importStepsFromHealth()
        }
    }

    @MainActor
    private func importStepsFromHealth(silentIfNoData: Bool = false) async {
        isLoadingSteps = true
        defer { isLoadingSteps = false }
        do {
            try await HealthKitSteps.requestAuthorization()
            let count = try await HealthKitSteps.steps(on: targetDate, calendar: calendar)
            stepsText = String(count)
            let day = calendar.startOfDay(for: targetDate)
            let label = calendar.isDateInToday(day) ? "today" : day.formatted(date: .abbreviated, time: .omitted)
            stepsSourceNote = "From Apple Health · \(label) · \(count.formatted()) steps"
            if !silentIfNoData {
                Haptics.light()
            }
            errorMessage = nil
        } catch let error as HealthKitStepsError {
            if silentIfNoData, case .noData = error { return }
            if silentIfNoData, case .unauthorized = error { return }
            errorMessage = error.localizedDescription
            stepsSourceNote = nil
        } catch {
            if silentIfNoData { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Validate the draft, then fetch-or-insert by dayKey on the *current*
    /// context. Fields the focused editor did not show are preserved from the
    /// row as it is now — not as it was when the sheet opened.
    private func save() {
        errorMessage = nil

        var steps: Int?
        if showsEvening {
            switch DailyCheckInMerge.steps(from: stepsText) {
            case .empty: steps = nil
            case .value(let value): steps = value
            case .invalid:
                errorMessage = "Steps must be a whole number ≥ 0."
                return
            }
        }

        let draft = DailyCheckInValues(
            restingPainAM: restingPainAM,
            dailyPainPM: dailyPainPM,
            steps: steps,
            phase: phase,
            notes: notes,
            declineSquatL: declineL,
            declineSquatR: declineR
        )
        if let issue = DailyCheckInMerge.validationError(draft: draft, focus: focus) {
            errorMessage = issue
            return
        }

        do {
            let current = try DailyCheckInStore.values(forDay: targetDate, context: modelContext, calendar: calendar)
            let merged = DailyCheckInMerge.merge(existing: current, draft: draft, focus: focus)
            try DailyCheckInStore.upsert(day: targetDate, values: merged, context: modelContext, calendar: calendar)
            Haptics.light()
            let previousMorningPain = current?.restingPainAM
            if showsMorning, previousMorningPain != restingPainAM, let nudge = morningNudge() {
                loadNudge = nudge
            } else {
                dismiss()
            }
        } catch {
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }

    private func morningNudge() -> LoadNudge? {
        LoadNudgeEvaluator.afterMorningPain(
            todayAM: restingPainAM,
            checkInDate: targetDate,
            checkIns: checkIns.map(\.snapshot),
            sessions: sessions.map(\.snapshot),
            calendar: calendar
        )
    }
}

#Preview("Morning") {
    NavigationStack {
        DailyCheckInEditor(focus: .morning)
    }
    .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
}

#Preview("Evening") {
    NavigationStack {
        DailyCheckInEditor(focus: .evening)
    }
    .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
}
