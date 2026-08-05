import SwiftUI
import SwiftData
import UIKit

/// Log a training session (PR-07). Creates with 24h = Pending.
struct SessionEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var sessions: [TrainingSession]

    var targetDate: Date = Date()

    @State private var phase: RehabPhase = .aFlareDeLoad
    @State private var sessionType: SessionType = .isometrics
    @State private var whatIDid: String = ""
    @State private var selectedPresetId: String?
    @State private var painDuring: Int? = nil
    @State private var painAfter: Int? = nil
    @State private var setsText: String = ""
    @State private var repsText: String = ""
    @State private var loadText: String = ""
    @State private var holdSecondsText: String = "30"
    @State private var notes: String = ""
    @State private var errorMessage: String?
    @State private var spacingWarning: String?
    @State private var didLoad = false

    private var calendar: Calendar { .current }
    private var settings: AppSettings? { settingsList.first }

    private var showsResistanceTracker: Bool {
        if let id = selectedPresetId,
           let preset = SessionPreset.all.first(where: { $0.id == id }) {
            return preset.tracksResistance
        }
        return false
    }

    private var isIsometricResistance: Bool {
        sessionType == .isometrics
    }

    var body: some View {
        Form {
            Section {
                Text(calendar.startOfDay(for: targetDate).formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Phase", selection: $phase) {
                    ForEach(RehabPhase.allCases) { p in
                        Text(p.title).tag(p)
                    }
                }
                .onChange(of: phase) { _, newPhase in
                    if let preferred = SessionPreset.resistancePreset(for: newPhase) {
                        applyPreset(preferred)
                    }
                }
            }

            Section("Preset") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(SessionPreset.forPhase(phase)) { preset in
                            Button(preset.label) {
                                applyPreset(preset)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(selectedPresetId == preset.id ? .accentColor : nil)
                        }
                    }
                }
            }

            Section("Session") {
                Picker("Type", selection: $sessionType) {
                    ForEach(SessionType.allCases) { t in
                        Text(t.title).tag(t)
                    }
                }
                TextField("What I did", text: $whatIDid, axis: .vertical)
                    .lineLimit(2...5)
            }

            if showsResistanceTracker {
                resistanceSection
            }

            Section("Pain") {
                PainScoreControl(title: "During (required)", value: $painDuring, allowsClear: false)
                PainScoreControl(title: "After (required)", value: $painAfter, allowsClear: false)
                if let painDuring, painDuring >= 5 {
                    Text("Pain ≥5 during — consider stopping or reducing next time.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }

            if let spacingWarning {
                Section {
                    Text(spacingWarning)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
        }
        .navigationTitle("Log session")
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
        .onAppear(perform: load)
        .onChange(of: sessionType) { _, _ in refreshSpacing() }
        .onChange(of: setsText) { _, _ in syncWhatIDidFromResistance() }
        .onChange(of: repsText) { _, _ in syncWhatIDidFromResistance() }
        .onChange(of: loadText) { _, _ in syncWhatIDidFromResistance() }
        .onChange(of: holdSecondsText) { _, _ in syncWhatIDidFromResistance() }
    }

    @ViewBuilder
    private var resistanceSection: some View {
        Section {
            HStack {
                labeledField(title: "Sets", text: $setsText, keyboard: .numberPad)
                labeledField(title: "Reps", text: $repsText, keyboard: .numberPad)
                labeledField(title: "Load (kg)", text: $loadText, keyboard: .decimalPad)
            }
            if isIsometricResistance {
                HStack {
                    Text("Time (sec)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("Seconds", text: $holdSecondsText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                        .accessibilityLabel("Hold time in seconds")
                }
            } else {
                HStack {
                    Text("Tempo")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("3s up · 3s down")
                        .font(.subheadline.monospacedDigit().weight(.medium))
                        .foregroundStyle(.primary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tempo: 3 seconds up, 3 seconds down")
            }
        } header: {
            Text("Leg extension resistance")
        } footer: {
            Text(
                isIsometricResistance
                    ? "Track machine load so Progress can plot pain vs resistance."
                    : "Heavy slow resistance uses a fixed 3 second up / 3 second down tempo."
            )
        }
    }

    private func labeledField(title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let settings = try? AppBootstrap.ensureSettings(context: modelContext) {
            phase = settings.currentPhase
        } else if let settings {
            phase = settings.currentPhase
        }
        // Prefer leg-extension resistance presets when in B/C; otherwise first phase preset.
        if let preferred = SessionPreset.resistancePreset(for: phase) {
            applyPreset(preferred)
        } else if let first = SessionPreset.forPhase(phase).first(where: { $0.id != "custom" }) {
            applyPreset(first)
        }
        refreshSpacing()
    }

    private func applyPreset(_ preset: SessionPreset) {
        selectedPresetId = preset.id
        sessionType = preset.sessionType
        if !preset.whatIDid.isEmpty {
            whatIDid = preset.whatIDid
        }
        if preset.tracksResistance {
            if setsText.isEmpty { setsText = "3" }
            if repsText.isEmpty {
                repsText = preset.sessionType == .isometrics ? "1" : "8"
            }
            if preset.sessionType == .isometrics, holdSecondsText.isEmpty {
                holdSecondsText = "30"
            }
            syncWhatIDidFromResistance()
        }
        refreshSpacing()
    }

    private func syncWhatIDidFromResistance() {
        guard showsResistanceTracker else { return }
        let sets = Int(setsText.trimmingCharacters(in: .whitespaces))
        let reps = Int(repsText.trimmingCharacters(in: .whitespaces))
        let load = Double(loadText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        let hold = Int(holdSecondsText.trimmingCharacters(in: .whitespaces))

        var parts: [String] = ["Leg extension"]
        if let sets, let reps {
            parts.append("\(sets)×\(reps)")
        }
        if let load {
            parts.append("@ \(TrainingSession.formatLoad(load)) kg")
        }
        if isIsometricResistance {
            if let hold {
                parts.append("\(hold)s hold")
            }
        } else {
            parts.append("3s up / 3s down")
        }
        whatIDid = parts.joined(separator: " ")
    }

    private func refreshSpacing() {
        let snaps = sessions.map(\.snapshot)
        if SessionSpacing.shouldWarnUnder48h(sessions: snaps, newType: sessionType, now: Date()) {
            spacingWarning = "Less than 48 hours since last hard session. Soft warning only — you can still save."
        } else {
            spacingWarning = nil
        }
    }

    private func save() {
        errorMessage = nil
        guard let painDuring, let painAfter else {
            errorMessage = "Pain during and after are required (0–10)."
            return
        }
        guard (0...10).contains(painDuring), (0...10).contains(painAfter) else {
            errorMessage = "Pain must be 0–10."
            return
        }
        let text = whatIDid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            errorMessage = "Describe what you did (or pick a preset)."
            return
        }

        var sets: Int?
        var reps: Int?
        var loadKg: Double?
        var holdSeconds: Int?

        if showsResistanceTracker {
            let setsTrim = setsText.trimmingCharacters(in: .whitespaces)
            let repsTrim = repsText.trimmingCharacters(in: .whitespaces)
            let loadTrim = loadText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
            let holdTrim = holdSecondsText.trimmingCharacters(in: .whitespaces)

            if !setsTrim.isEmpty {
                guard let parsed = Int(setsTrim), parsed > 0 else {
                    errorMessage = "Sets must be a positive whole number."
                    return
                }
                sets = parsed
            }
            if !repsTrim.isEmpty {
                guard let parsed = Int(repsTrim), parsed > 0 else {
                    errorMessage = "Reps must be a positive whole number."
                    return
                }
                reps = parsed
            }
            if !loadTrim.isEmpty {
                guard let parsed = Double(loadTrim), parsed >= 0 else {
                    errorMessage = "Load must be a number (kg)."
                    return
                }
                loadKg = parsed
            }
            if isIsometricResistance, !holdTrim.isEmpty {
                guard let parsed = Int(holdTrim), parsed > 0 else {
                    errorMessage = "Hold time must be a positive number of seconds."
                    return
                }
                holdSeconds = parsed
            }
        }

        let session = TrainingSession(
            date: targetDate,
            phase: phase,
            sessionType: sessionType,
            whatIDid: text,
            painDuring: painDuring,
            painAfter: painAfter,
            sets: sets,
            reps: reps,
            loadKg: loadKg,
            holdSeconds: holdSeconds,
            calendar: calendar
        )
        session.notes = notes
        modelContext.insert(session)
        do {
            try modelContext.save()
            if let settings, settings.notificationsEnabled {
                NotificationScheduler.schedulePending(
                    sessionId: session.id,
                    sessionDate: session.date,
                    snoozedUntil: nil,
                    amHour: settings.amReminderHour,
                    amMinute: settings.amReminderMinute
                )
            }
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        SessionEditor()
    }
    .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
    .preferredColorScheme(.dark)
}
