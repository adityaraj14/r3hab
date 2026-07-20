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
    @State private var morningStiffness: Int?
    @State private var dailyPainPM: Int?
    @State private var stepsText: String = ""
    @State private var phase: RehabPhase = .aFlareDeLoad
    @State private var notes: String = ""
    @State private var declineL: Int?
    @State private var declineR: Int?
    @State private var existing: DailyCheckIn?
    @State private var errorMessage: String?
    @State private var didLoad = false

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
                PainScoreControl(title: "Resting pain AM", value: $restingPainAM)
                PainScoreControl(title: "Morning stiffness", value: $morningStiffness)
            }

            Section("Evening") {
                PainScoreControl(title: "Daily activities pain PM", value: $dailyPainPM)
                TextField("Steps (optional)", text: $stepsText)
                    .keyboardType(.numberPad)
            }

            Section("Optional · decline squat") {
                PainScoreControl(title: "Left", value: $declineL)
                PainScoreControl(title: "Right", value: $declineR)
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
    }

    private var dayLabel: String {
        let d = calendar.startOfDay(for: targetDate)
        return d.formatted(date: .complete, time: .omitted)
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        let day = calendar.startOfDay(for: targetDate)
        let key = DailyCheckIn.dayKey(for: day, calendar: calendar)

        // Seed phase from settings
        if let settings = try? AppBootstrap.ensureSettings(context: modelContext) {
            phase = settings.currentPhase
        }

        let predicate = #Predicate<DailyCheckIn> { $0.dayKey == key }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        if let row = try? modelContext.fetch(descriptor).first {
            existing = row
            restingPainAM = row.restingPainAM
            morningStiffness = row.morningStiffness
            dailyPainPM = row.dailyPainPM
            stepsText = row.steps.map(String.init) ?? ""
            phase = row.phase
            notes = row.notes
            declineL = row.declineSquatL
            declineR = row.declineSquatR
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
        for score in [restingPainAM, morningStiffness, dailyPainPM, declineL, declineR] {
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
        row.morningStiffness = morningStiffness
        row.dailyPainPM = dailyPainPM
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
