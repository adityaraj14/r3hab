import SwiftUI
import SwiftData
import UIKit

/// Log or edit a training session (seated knee extension iso/HSR + 24h loop).
struct SessionEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var sessions: [TrainingSession]

    var targetDate: Date = Date()
    var existing: TrainingSession?
    var focus: SessionLogFocus = .general

    @State private var phase: RehabPhase = .aFlareDeLoad
    @State private var sessionType: SessionType = .isometrics
    @State private var whatIDid: String = ""
    @State private var selectedPresetId: String?
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
        showsResistance && !usesIsoHolds && sessionType == .hsrStrength
    }

    private var navigationTitleText: String {
        if isEditing { return "Edit session" }
        return "Log session"
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

                Picker("Phase", selection: $phase) {
                    ForEach(RehabPhase.allCases) { p in
                        Text(p.title).tag(p)
                    }
                }
            } header: {
                Text("Patellar tendinopathy")
            }

            Section("Exercise") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(presetsForPhase) { preset in
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
                        footer: "Reps = holds · time per hold · load (lbs). Same pattern as pure isometrics.",
                        sets: $warmupSets,
                        isoStyle: true
                    )
                }

                setListSection(
                    title: usesIsoHolds ? "Working holds" : "Working sets",
                    footer: usesIsoHolds
                        ? "Each hold is one side. Both knees stay in this session — one 24h resolve tomorrow. Load (lbs)."
                        : "L and R rows are one session. One 24h resolve. Load (lbs). Volume = Σ reps × load.",
                    sets: $workSets,
                    isoStyle: usesIsoHolds
                )

                if volumePreview > 0 {
                    Section {
                        LabeledContent("Session volume", value: "\(TrainingSession.formatLoad(volumePreview)) lbs·reps")
                        if let maxL = ResistanceMath.maxLoad(workSets + warmupSets) {
                            LabeledContent("Max load", value: LoadCopy.labeled(maxL))
                        }
                    } footer: {
                        Text("Progress charts plot daily volume (and max load in the legend).")
                    }
                }
            }

            Section {
                PainScoreControl(title: "During (required)", value: $painDuring, allowsClear: false)
                PainScoreControl(title: "After (required)", value: $painAfter, allowsClear: false)
            } header: {
                Text("Pain")
            } footer: {
                Text("Starts empty. Both sides share this score and one 24h resolve.")
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

    private var presetsForPhase: [SessionPreset] {
        SessionPreset.forPhase(phase)
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
                        Text(rowTitle(isoStyle: isoStyle, index: index, set: sets.wrappedValue[index]))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if !title.lowercased().contains("warm") {
                            Picker(
                                "Side",
                                selection: bindingSide(sets, index: index)
                            ) {
                                Text("L").tag(KneeSide.left)
                                Text("R").tag(KneeSide.right)
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 96)
                        }
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
                            title: "Load (lbs)",
                            value: bindingLoad(sets, index: index)
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            if title.lowercased().contains("warm") {
                Button {
                    sets.wrappedValue.append(
                        ResistanceSet(
                            reps: isoStyle ? 1 : 3,
                            loadLbs: nil,
                            holdSeconds: isoStyle ? 30 : 30,
                            isWarmup: true
                        )
                    )
                } label: {
                    Label("Add warm-up", systemImage: "plus.circle")
                }
            } else {
                HStack {
                    Button {
                        appendWorkSet(to: sets, isoStyle: isoStyle, side: .left)
                    } label: {
                        Label(isoStyle ? "Add L hold" : "Add L set", systemImage: "plus.circle")
                    }
                    Button {
                        appendWorkSet(to: sets, isoStyle: isoStyle, side: .right)
                    } label: {
                        Label(isoStyle ? "Add R hold" : "Add R set", systemImage: "plus.circle")
                    }
                }
            }
        } header: {
            Text(title)
        } footer: {
            Text(footer)
        }
    }

    private func rowTitle(isoStyle: Bool, index: Int, set: ResistanceSet) -> String {
        let kind = isoStyle ? "Hold" : "Set"
        if let side = set.side {
            return "\(side.shortLabel) \(kind)"
        }
        return "\(kind) \(index + 1)"
    }

    private func bindingSide(_ sets: Binding<[ResistanceSet]>, index: Int) -> Binding<KneeSide> {
        Binding(
            get: {
                guard sets.wrappedValue.indices.contains(index) else { return .left }
                return sets.wrappedValue[index].side ?? .left
            },
            set: { new in
                guard sets.wrappedValue.indices.contains(index) else { return }
                sets.wrappedValue[index].side = new
            }
        )
    }

    private func appendWorkSet(to sets: Binding<[ResistanceSet]>, isoStyle: Bool, side: KneeSide) {
        sets.wrappedValue.append(
            ResistanceSet(
                reps: isoStyle ? 4 : 8,
                loadLbs: nil,
                holdSeconds: isoStyle ? 30 : nil,
                isWarmup: false,
                side: side
            )
        )
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
            usesIsoHolds = existing.sessionType == .isometrics
            let all = existing.resistanceSets()
            warmupSets = all.filter(\.isWarmup)
            workSets = all.filter { !$0.isWarmup }
            if workSets.isEmpty && warmupSets.isEmpty {
                seedDefaultSets()
            }
            selectedPresetId = SessionPreset.forPhase(phase)
                .first { $0.sessionType == existing.sessionType && $0.tracksResistance }?.id
            refreshSpacing()
            return
        }

        if let settings = try? AppBootstrap.ensureSettings(context: modelContext) {
            phase = settings.currentPhase
        }
        switch focus {
        case .kneeResistance, .general:
            if let preferred = SessionPreset.resistancePreset(for: phase) {
                applyPreset(preferred)
            } else {
                applyPreset(SessionPreset.all.first { $0.id == SessionPreset.seatedExtensionIsometricId }!)
            }
        }
        refreshSpacing()
    }

    private func applyPreset(_ preset: SessionPreset) {
        selectedPresetId = preset.id
        sessionType = preset.sessionType
        usesIsoHolds = preset.usesIsoHoldLogging || preset.sessionType == .isometrics
        if !preset.whatIDid.isEmpty {
            whatIDid = preset.whatIDid
        }
        if !isEditing {
            workSets = []
            warmupSets = []
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
                    ResistanceSet(reps: 4, loadLbs: nil, holdSeconds: 30, isWarmup: false, side: .left),
                    ResistanceSet(reps: 4, loadLbs: nil, holdSeconds: 30, isWarmup: false, side: .right)
                ]
            }
        } else {
            if warmupSets.isEmpty {
                warmupSets = [
                    ResistanceSet(reps: 3, loadLbs: nil, holdSeconds: 30, isWarmup: true)
                ]
            }
            if workSets.isEmpty {
                workSets = [
                    ResistanceSet(reps: 8, loadLbs: nil, holdSeconds: nil, isWarmup: false, side: .left),
                    ResistanceSet(reps: 8, loadLbs: nil, holdSeconds: nil, isWarmup: false, side: .right)
                ]
            }
        }
    }

    private func syncWhatIDid() {
        let name: String
        if let id = selectedPresetId, let p = SessionPreset.all.first(where: { $0.id == id }) {
            name = p.label
        } else {
            name = "Seated knee extension"
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
            let structured = lower.contains("wu") || lower.contains("lb") || lower.contains("lbs") || lower.contains("×")
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

        if let existing {
            existing.phase = phase
            existing.sessionType = sessionType
            existing.whatIDid = text
            existing.painDuring = painDuring
            existing.painAfter = painAfter
            existing.notes = notes
            existing.track = .knee
            existing.loadRegion = .knee
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
            loadRegion: .knee,
            track: .knee,
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
        SessionEditor(focus: .kneeResistance)
    }
    .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
    .preferredColorScheme(.dark)
}
