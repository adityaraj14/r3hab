import SwiftUI
import SwiftData

/// Create/edit one daily check-in (partial AM/PM save OK).
struct DailyCheckInEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Calendar day to edit (start-of-day). Defaults to today.
    var targetDate: Date = Date()
    var focusPM: Bool = false

    @State private var restingPainAM: Int?
    @State private var dailyPainPM: Int?
    @State private var lowerBackPainAM: Int?
    @State private var lowerBackPainPM: Int?
    @State private var stepsText: String = ""
    @State private var phase: RehabPhase = .aFlareDeLoad
    @State private var notes: String = ""
    @State private var declineL: Int?
    @State private var declineR: Int?
    @State private var existing: DailyCheckIn?
    @State private var errorMessage: String?
    @State private var didLoad = false
    @State private var isLoadingSteps = false
    @State private var stepsSourceNote: String?

    private var calendar: Calendar { .current }

    var body: some View {
        Form {
            Section {
                Text(dayLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Phase", selection: $phase) {
                    ForEach(RehabPhase.allCases) { p in
                        Text(p.title).tag(p)
                    }
                }
            }

            Section("Morning") {
                PainScoreControl(title: "Knee resting pain", value: $restingPainAM)
                PainScoreControl(title: "Lower back pain", value: $lowerBackPainAM)
            }

            Section {
                PainScoreControl(title: "Knee daily activities pain", value: $dailyPainPM)
                PainScoreControl(title: "Lower back pain", value: $lowerBackPainPM)

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
                Text("Knee and lower back each use a 0–10 scale. Steps power Phase A “near-normal walking” progress. Prefer Import from Health (Watch) — you can still edit the number.")
            }

            Section {
                PainScoreControl(title: "Left", value: $declineL)
                PainScoreControl(title: "Right", value: $declineR)
            } header: {
                Text("Optional · single-leg decline squat")
            } footer: {
                Text(declineSquatFooter)
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
        .navigationTitle(existing == nil ? "New check-in" : "Edit check-in")
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
        .task {
            // Auto-fill steps from Health when empty (today or backdated day).
            guard stepsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            guard HealthKitSteps.isAvailable else { return }
            await importStepsFromHealth(silentIfNoData: true)
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

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        let day = calendar.startOfDay(for: targetDate)
        let key = DailyCheckIn.dayKey(for: day, calendar: calendar)

        if let settings = try? AppBootstrap.ensureSettings(context: modelContext) {
            phase = settings.currentPhase
        }

        let predicate = #Predicate<DailyCheckIn> { $0.dayKey == key }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        if let row = try? modelContext.fetch(descriptor).first {
            existing = row
            restingPainAM = row.restingPainAM
            dailyPainPM = row.dailyPainPM
            lowerBackPainAM = row.lowerBackPainAM
            lowerBackPainPM = row.lowerBackPainPM
            stepsText = row.steps.map(String.init) ?? ""
            phase = row.phase
            notes = row.notes
            declineL = row.declineSquatL
            declineR = row.declineSquatR
            if row.steps != nil {
                stepsSourceNote = "Saved value — tap Health to refresh from Apple Watch."
            }
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

    private func save() {
        errorMessage = nil
        if let stepsText = stepsText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty {
            guard let steps = Int(stepsText), steps >= 0 else {
                errorMessage = "Steps must be a whole number ≥ 0."
                return
            }
            applySave(steps: steps)
        } else {
            applySave(steps: nil)
        }
    }

    private func applySave(steps: Int?) {
        for score in [restingPainAM, dailyPainPM, lowerBackPainAM, lowerBackPainPM, declineL, declineR] {
            if let score, !(0...10).contains(score) {
                errorMessage = "Pain scores must be 0–10."
                return
            }
        }

        let day = calendar.startOfDay(for: targetDate)
        let row: DailyCheckIn
        if let existing {
            row = existing
        } else {
            row = DailyCheckIn(date: day, calendar: calendar, phase: phase)
            modelContext.insert(row)
        }

        row.restingPainAM = restingPainAM
        row.dailyPainPM = dailyPainPM
        row.lowerBackPainAM = lowerBackPainAM
        row.lowerBackPainPM = lowerBackPainPM
        row.steps = steps
        row.phase = phase
        row.notes = notes
        row.declineSquatL = declineL
        row.declineSquatR = declineR
        row.updatedAt = Date()

        do {
            try modelContext.save()
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

#Preview {
    NavigationStack {
        DailyCheckInEditor()
    }
    .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
}
