import SwiftUI
import SwiftData
import UIKit

/// Log or edit a training session (multi-set resistance + dual rehab tracks).
struct SessionEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var sessions: [TrainingSession]

    var targetDate: Date = Date()
    var existing: TrainingSession?
    var focus: SessionLogFocus = .general
    /// When opening a new log for a specific rehab issue.
    var track: RehabTrackID = .knee

    @State private var phase: RehabPhase = .aFlareDeLoad
    @State private var sessionType: SessionType = .isometrics
    @State private var whatIDid: String = ""
    @State private var selectedPresetId: String?
    @State private var activeTrack: RehabTrackID = .knee
    @State private var workSets: [ResistanceSet] = []
    @State private var warmupSets: [ResistanceSet] = []
    @State private var usesIsoHolds = false
    @State private var painDuring: Int? = nil
    @State private var painAfter: Int? = nil
    @State private var notes: String = ""
    @State private var errorMessage: String?
    @State private var spacingWarning: String?
    @State private var didLoad = false
    @State private var showResolve = false

    private var calendar: Calendar { .current }
    private var settings: AppSettings? { settingsList.first }
    private var isEditing: Bool { existing != nil }

    private var showsResistance: Bool {
        if let id = selectedPresetId,
           let p = SessionPreset.all.first(where: { $0.id == id }) {
            return p.tracksResistance
        }
        return focus != .general || !workSets.isEmpty || !warmupSets.isEmpty
            || sessionType == .isometrics || sessionType == .hsrStrength
    }

    private var showsWarmup: Bool {
        showsResistance && !usesIsoHolds && activeTrack == .knee && sessionType == .hsrStrength
    }

    private var navigationTitleText: String {
        if isEditing { return "Edit session" }
        switch focus {
        case .lowerBackResistance: return "Log back session"
        case .kneeResistance: return "Log knee session"
        case .general: return "Log session"
        }
    }

    private var volumePreview: Double {
        ResistanceMath.totalVolume(workSets) + ResistanceMath.totalVolume(warmupSets)
    }

    var body: some View {
        Form {
            Section {
                Text(displayDate.formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !isEditing {
                    Picker("Rehab track", selection: $activeTrack) {
                        if settings?.isKneeTrackActive != false {
                            Text("Knee").tag(RehabTrackID.knee)
                        }
                        if settings?.isBackTrackActive != false {
                            Text("Low back").tag(RehabTrackID.lowerBack)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: activeTrack) { _, new in
                        applyTrackDefault(new)
                    }
                } else {
                    LabeledContent("Track", value: activeTrack.title)
                }

                if activeTrack == .knee {
                    Picker("Knee phase", selection: $phase) {
                        ForEach(RehabPhase.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                } else {
                    Text(RehabTemplate.lowerBack.objective80_20)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(activeTrack == .knee ? "Knee · patellar tendon" : "Low back · QL / trunk")
            }

            Section("Exercise") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(presetsForCurrentTrack) { preset in
                            Button(preset.label) { applyPreset(preset) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(selectedPresetId == preset.id ? .accentColor : nil)
                        }
                    }
                }
                Picker("Type", selection: $sessionType) {
                    ForEach(SessionType.allCases) { t in
                        Text(t.title).tag(t)
                    }
                }
                .onChange(of: sessionType) { _, new in
                    usesIsoHolds = (new == .isometrics)
                    refreshSpacing()
                }
                TextField("What I did", text: $whatIDid, axis: .vertical)
                    .lineLimit(2...4)
            }

            if showsResistance {
                if showsWarmup {
                    setListSection(
                        title: "Warm-up (isometric holds)",
                        footer: "Reps = holds · time per hold · load (lb). Same pattern as pure isometrics.",
                        sets: $warmupSets,
                        isoStyle: true
                    )
                }

                setListSection(
                    title: usesIsoHolds ? "Working holds" : "Working sets",
                    footer: usesIsoHolds
                        ? "Each row is one hold: reps (count), time (sec), load (lb). Add rows as needed."
                        : "Each row is one set with its own reps and load (lb). Volume = Σ reps × load.",
                    sets: $workSets,
                    isoStyle: usesIsoHolds
                )

                if volumePreview > 0 {
                    Section {
                        LabeledContent("Session volume", value: "\(TrainingSession.formatLoad(volumePreview)) lb·reps")
                        if let maxL = ResistanceMath.maxLoad(workSets + warmupSets) {
                            LabeledContent("Max load", value: "\(TrainingSession.formatLoad(maxL)) lb")
                        }
                    } footer: {
                        Text("Progress charts plot daily volume (and max load in the legend).")
                    }
                }
            }

            Section("Pain") {
                PainScoreControl(title: "During (required)", value: $painDuring, allowsClear: false)
                PainScoreControl(title: "After (required)", value: $painAfter, allowsClear: false)
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }

            if isEditing, let existing, existing.response24h == .pending {
                Section {
                    Button("Resolve 24h response…") { showResolve = true }
                }
            }

            if let spacingWarning {
                Section {
                    Text(spacingWarning).font(.footnote).foregroundStyle(.orange)
                }
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
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
                Button("Save") { save() }.fontWeight(.semibold)
            }
        }
        .onAppear(perform: load)
        .onChange(of: workSets) { _, _ in syncWhatIDid() }
        .onChange(of: warmupSets) { _, _ in syncWhatIDid() }
        .sheet(isPresented: $showResolve) {
            if let existing { Resolve24hSheet(session: existing) }
        }
    }

    private var displayDate: Date {
        if let existing { return calendar.startOfDay(for: existing.date) }
        return calendar.startOfDay(for: targetDate)
    }

    private var presetsForCurrentTrack: [SessionPreset] {
        SessionPreset.forTrack(activeTrack, phase: phase)
    }

    @ViewBuilder
    private func setListSection(
        title: String,
        footer: String,
        sets: Binding<[ResistanceSet]>,
        isoStyle: Bool
    ) -> some View {
        Section {
            ForEach(Array(sets.wrappedValue.enumerated()), id: \.element.id) { index, _ in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(isoStyle ? "Hold \(index + 1)" : "Set \(index + 1)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if sets.wrappedValue.count > 1 {
                            Button(role: .destructive) {
                                sets.wrappedValue.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    HStack {
                        labeledIntField(
                            title: isoStyle ? "Reps" : "Reps",
                            value: bindingReps(sets, index: index)
                        )
                        if isoStyle {
                            labeledIntField(
                                title: "Time (s)",
                                value: bindingHold(sets, index: index)
                            )
                        }
                        labeledLoadField(
                            title: "Load (lb)",
                            value: bindingLoad(sets, index: index)
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            Button {
                sets.wrappedValue.append(
                    ResistanceSet(
                        reps: isoStyle ? 1 : 8,
                        loadLbs: nil,
                        holdSeconds: isoStyle ? 30 : nil,
                        isWarmup: title.lowercased().contains("warm")
                    )
                )
            } label: {
                Label(isoStyle ? "Add hold" : "Add set", systemImage: "plus.circle")
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
        }
    }

    private func bindingReps(_ sets: Binding<[ResistanceSet]>, index: Int) -> Binding<String> {
        Binding(
            get: {
                guard sets.wrappedValue.indices.contains(index),
                      let r = sets.wrappedValue[index].reps else { return "" }
                return String(r)
            },
            set: { new in
                guard sets.wrappedValue.indices.contains(index) else { return }
                sets.wrappedValue[index].reps = Int(new)
            }
        )
    }

    private func bindingHold(_ sets: Binding<[ResistanceSet]>, index: Int) -> Binding<String> {
        Binding(
            get: {
                guard sets.wrappedValue.indices.contains(index),
                      let h = sets.wrappedValue[index].holdSeconds else { return "" }
                return String(h)
            },
            set: { new in
                guard sets.wrappedValue.indices.contains(index) else { return }
                sets.wrappedValue[index].holdSeconds = Int(new)
            }
        )
    }

    private func bindingLoad(_ sets: Binding<[ResistanceSet]>, index: Int) -> Binding<String> {
        Binding(
            get: {
                guard sets.wrappedValue.indices.contains(index),
                      let l = sets.wrappedValue[index].loadLbs else { return "" }
                return TrainingSession.formatLoad(l)
            },
            set: { new in
                guard sets.wrappedValue.indices.contains(index) else { return }
                let trimmed = new.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
                sets.wrappedValue[index].loadLbs = trimmed.isEmpty ? nil : Double(trimmed)
            }
        )
    }

    private func labeledIntField(title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: value)
                .keyboardType(.numberPad)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeledLoadField(title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title, text: value)
                .keyboardType(.decimalPad)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true

        if let existing {
            phase = existing.phase
            sessionType = existing.sessionType
            whatIDid = existing.whatIDid
            painDuring = existing.painDuring
            painAfter = existing.painAfter
            notes = existing.notes
            activeTrack = existing.track
            usesIsoHolds = existing.sessionType == .isometrics
            let all = existing.resistanceSets()
            warmupSets = all.filter(\.isWarmup)
            workSets = all.filter { !$0.isWarmup }
            if workSets.isEmpty && warmupSets.isEmpty {
                seedDefaultSets()
            }
            selectedPresetId = SessionPreset.forTrack(activeTrack, phase: phase)
                .first { $0.sessionType == existing.sessionType && $0.tracksResistance }?.id
            refreshSpacing()
            return
        }

        if let settings = try? AppBootstrap.ensureSettings(context: modelContext) {
            phase = settings.currentPhase
        }
        switch focus {
        case .lowerBackResistance:
            activeTrack = .lowerBack
            applyPreset(SessionPreset.hipThrust)
        case .kneeResistance:
            activeTrack = .knee
            if let preferred = SessionPreset.resistancePreset(for: phase) {
                applyPreset(preferred)
            } else {
                applyPreset(SessionPreset.all.first { $0.id == SessionPreset.legExtensionIsometricId }!)
            }
        case .general:
            activeTrack = track
            applyTrackDefault(track)
        }
        refreshSpacing()
    }

    private func applyTrackDefault(_ track: RehabTrackID) {
        activeTrack = track
        switch track {
        case .knee:
            if let preferred = SessionPreset.resistancePreset(for: phase) {
                applyPreset(preferred)
            }
        case .lowerBack:
            applyPreset(SessionPreset.sidePlank)
        }
    }

    private func applyPreset(_ preset: SessionPreset) {
        selectedPresetId = preset.id
        sessionType = preset.sessionType
        activeTrack = preset.track
        usesIsoHolds = preset.usesIsoHoldLogging || preset.sessionType == .isometrics
        if !preset.whatIDid.isEmpty {
            whatIDid = preset.whatIDid
        }
        seedDefaultSets()
        syncWhatIDid()
        refreshSpacing()
    }

    private func seedDefaultSets() {
        if usesIsoHolds {
            warmupSets = []
            if workSets.isEmpty {
                workSets = [
                    ResistanceSet(reps: 4, loadLbs: nil, holdSeconds: 30, isWarmup: false)
                ]
            }
        } else {
            if activeTrack == .knee && warmupSets.isEmpty {
                warmupSets = [
                    ResistanceSet(reps: 3, loadLbs: nil, holdSeconds: 30, isWarmup: true)
                ]
            }
            if workSets.isEmpty {
                workSets = [
                    ResistanceSet(reps: 8, loadLbs: nil, holdSeconds: nil, isWarmup: false),
                    ResistanceSet(reps: 8, loadLbs: nil, holdSeconds: nil, isWarmup: false),
                    ResistanceSet(reps: 8, loadLbs: nil, holdSeconds: nil, isWarmup: false)
                ]
            }
        }
    }

    private func syncWhatIDid() {
        let name: String
        if let id = selectedPresetId, let p = SessionPreset.all.first(where: { $0.id == id }) {
            name = p.label
        } else {
            name = activeTrack == .lowerBack ? "Back session" : "Leg extension"
        }
        var parts = [name]
        let wu = warmupSets.filter { $0.reps != nil || $0.loadLbs != nil || $0.holdSeconds != nil }
        let work = workSets.filter { $0.reps != nil || $0.loadLbs != nil || $0.holdSeconds != nil }
        if !wu.isEmpty {
            parts.append("WU " + wu.map(\.summary).joined(separator: ", "))
        }
        if !work.isEmpty {
            parts.append(work.map(\.summary).joined(separator: ", "))
        }
        if work.isEmpty && wu.isEmpty { return }
        // Don't clobber free-text history on edit unless it looks structured
        if isEditing, !whatIDid.isEmpty {
            let lower = whatIDid.lowercased()
            let structured = lower.contains("wu") || lower.contains("lb") || lower.contains("×")
                || lower.contains("x") || lower.contains("set")
            if !structured { return }
        }
        whatIDid = parts.joined(separator: " · ")
    }

    private func refreshSpacing() {
        guard !isEditing else {
            spacingWarning = nil
            return
        }
        let snaps = sessions.map(\.snapshot)
        if SessionSpacing.shouldWarnUnder48h(sessions: snaps, newType: sessionType, now: Date()) {
            spacingWarning = "Less than 48 hours since last hard session. Soft warning only."
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

        // Normalize warmup flags
        var wu = warmupSets.map { var s = $0; s.isWarmup = true; return s }
        var work = workSets.map { var s = $0; s.isWarmup = false; return s }
        // Drop fully empty rows
        wu = wu.filter { $0.reps != nil || $0.loadLbs != nil || $0.holdSeconds != nil }
        work = work.filter { $0.reps != nil || $0.loadLbs != nil || $0.holdSeconds != nil }

        for row in wu + work {
            if let r = row.reps, r <= 0 {
                errorMessage = "Reps must be positive."
                return
            }
            if let h = row.holdSeconds, h <= 0 {
                errorMessage = "Hold time must be positive."
                return
            }
            if let l = row.loadLbs, l < 0 {
                errorMessage = "Load must be ≥ 0."
                return
            }
        }

        let allSets = wu + work
        let region = activeTrack.loadRegion

        if let existing {
            existing.phase = phase
            existing.sessionType = sessionType
            existing.whatIDid = text
            existing.painDuring = painDuring
            existing.painAfter = painAfter
            existing.notes = notes
            existing.track = activeTrack
            existing.loadRegion = region
            existing.setResistanceSets(allSets)
            existing.updatedAt = Date()
            do {
                try modelContext.save()
                Haptics.success()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        let session = TrainingSession(
            date: targetDate,
            phase: phase,
            sessionType: sessionType,
            whatIDid: text,
            painDuring: painDuring,
            painAfter: painAfter,
            loadRegion: region,
            track: activeTrack,
            resistanceSets: allSets,
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
        SessionEditor(focus: .kneeResistance, track: .knee)
    }
    .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
    .preferredColorScheme(.dark)
}
