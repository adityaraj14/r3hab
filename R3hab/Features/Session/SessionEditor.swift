import SwiftUI
import SwiftData

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
    @State private var painDuring: Int? = nil
    @State private var painAfter: Int? = nil
    @State private var notes: String = ""
    @State private var errorMessage: String?
    @State private var spacingWarning: String?
    @State private var didLoad = false

    private var calendar: Calendar { .current }
    private var settings: AppSettings? { settingsList.first }

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
                .onChange(of: phase) { _, _ in
                    // keep type/text; presets list updates
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
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let settings = try? AppBootstrap.ensureSettings(context: modelContext) {
            phase = settings.currentPhase
        } else if let settings {
            phase = settings.currentPhase
        }
        // Default presets for current phase
        if let first = SessionPreset.forPhase(phase).first(where: { $0.id != "custom" }) {
            applyPreset(first)
        }
        refreshSpacing()
    }

    private func applyPreset(_ preset: SessionPreset) {
        sessionType = preset.sessionType
        if !preset.whatIDid.isEmpty {
            whatIDid = preset.whatIDid
        }
        refreshSpacing()
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

        let session = TrainingSession(
            date: targetDate,
            phase: phase,
            sessionType: sessionType,
            whatIDid: text,
            painDuring: painDuring,
            painAfter: painAfter,
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
