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
                    PainScoreControl(title: "Knee resting pain", value: $restingPainAM)
                } header: {
                    Text("Morning")
                } footer: {
                    Text("Resting knee pain before you start the day, 0–10. Evening pain and steps are logged separately.")
                }
            }

            if showsEvening {
                Section {
                    PainScoreControl(title: "Knee daily activities pain", value: $dailyPainPM)

                    HStack {
                        TextField("Steps", text: $stepsText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.plain)
                            .accessibilityLabel("Steps")
                        if isLoadingSteps {
                            ProgressView()
                        } else if HealthKitSteps.isAvailable {
                            Button("Health") {
                                Task { await importStepsFromHealth() }
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
                    Text("Pain during the day’s activities, 0–10. Steps power Phase A “near-normal walking” progress. Prefer Import from Health — you can still edit the number.")
                }

                Section {
                    PainScoreControl(title: "Left", value: $declineL)
                    PainScoreControl(title: "Right", value: $declineR)
                } header: {
                    Text("Optional · single-leg decline squat")
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
            await importStepsFromHealth(silentIfNoData: true)
        }
    }

    private var navigationTitleText: String {
        switch focus {
        case .morning:
            return morningPainOnLoad != nil ? "Edit morning" : "Log morning"
        case .evening:
            return eveningPainOnLoad != nil ? "Edit evening" : "Log evening"
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
        Not required every day. This is a standard tendon monitoring test (single-leg squat on a decline board or similar): rate knee/tendon pain 0–10 after a few controlled reps each side. Useful 1–3×/week or when deciding load — skip on flare days if it feels unwise. Resting AM and evening pain matter more for daily tracking.
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
            stepsSourceNote = "Saved value — tap Health to refresh from Apple Watch."
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
