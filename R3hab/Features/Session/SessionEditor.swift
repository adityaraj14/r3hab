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
    @AppStorage("sessionLaterality") private var storedLateralityRaw: String = SetLaterality.bilateral.rawValue
    @State private var laterality: SetLaterality = .bilateral
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
                if let settings {
                    Text("Primary: \(settings.primaryLoad.title)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
                    warmupSection
                }

                workSetsSection

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
        SessionPreset.forPhase(phase, primaryLoadID: primaryLoadID)
    }

    private var primaryLoadID: String {
        settings?.primaryLoadID ?? PrimaryLoadCatalog.defaultID
    }

    private var lateralityBinding: Binding<SetLaterality> {
        Binding(
            get: { laterality },
            set: { newValue in
                guard newValue != laterality else { return }
                laterality = newValue
                storedLateralityRaw = newValue.rawValue
                workSets = SessionSummary.applyLaterality(newValue, to: workSets)
            }
        )
    }

    private var workPairs: [WorkSetPair] {
        SessionSummary.groupWorkSets(workSets)
    }

    private var workSetsSection: some View {
        Section {
            Picker("Legs", selection: lateralityBinding) {
                ForEach(SetLaterality.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            ForEach(Array(workPairs.enumerated()), id: \.element.id) { index, pair in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(usesIsoHolds ? "Hold \(index + 1)" : "Set \(index + 1)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if workPairs.count > 1 {
                            Button(role: .destructive) {
                                removePair(pair)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    HStack {
                        labeledIntField(title: "Reps", value: bindingPairReps(pair))
                        if usesIsoHolds {
                            labeledIntField(title: "Time (s)", value: bindingPairHold(pair))
                        }
                        if laterality == .bilateral {
                            labeledLoadField(title: "Load (lbs)", value: bindingPairLoad(pair, side: nil))
                        } else {
                            labeledLoadField(title: "L lbs", value: bindingPairLoad(pair, side: .left))
                            labeledLoadField(title: "R lbs", value: bindingPairLoad(pair, side: .right))
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Button {
                appendWorkPair()
            } label: {
                Label(usesIsoHolds ? "Add hold" : "Add set", systemImage: "plus.circle")
            }
        } header: {
            Text(usesIsoHolds ? "Working holds" : "Working sets")
        } footer: {
            Text(laterality == .bilateral
                 ? "One load for both knees. Switch to Each leg if left and right use different loads. One 24h resolve for the session."
                 : "Each set logs left and right separately so loads can differ. One 24h resolve for the session.")
        }
    }

    private var warmupSection: some View {
        Section {
            ForEach(Array(warmupSets.enumerated()), id: \.element.id) { index, _ in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Warm-up \(index + 1)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if warmupSets.count > 1 {
                            Button(role: .destructive) {
                                warmupSets.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    HStack {
                        labeledIntField(title: "Reps", value: bindingWarmupReps(index))
                        labeledIntField(title: "Time (s)", value: bindingWarmupHold(index))
                        labeledLoadField(title: "Load (lbs)", value: bindingWarmupLoad(index))
                    }
                }
                .padding(.vertical, 4)
            }
            Button {
                warmupSets.append(
                    ResistanceSet(reps: 2, loadLbs: nil, holdSeconds: 30, isWarmup: true)
                )
            } label: {
                Label("Add warm-up", systemImage: "plus.circle")
            }
        } header: {
            Text("Warm-up (isometric holds)")
        } footer: {
            Text("Reps = holds · time per hold · load (lbs). Same load for both knees.")
        }
    }

    private func appendWorkPair() {
        let last = workPairs.last
        let reps = last?.reps ?? (usesIsoHolds ? 4 : 8)
        let hold = last?.holdSeconds ?? (usesIsoHolds ? 30 : nil)
        workSets.append(contentsOf: SessionSummary.makePair(
            reps: reps,
            loadLbs: last?.leftLoad,
            holdSeconds: hold,
            isWarmup: false,
            rightLoadLbs: laterality == .unilateral ? last?.rightLoad : last?.leftLoad
        ))
    }

    private func removePair(_ pair: WorkSetPair) {
        let ids = Set([pair.left.id, pair.right?.id].compactMap { $0 })
        workSets.removeAll { ids.contains($0.id) }
    }

    private func updateSets(matching ids: [UUID], mutate: (inout ResistanceSet) -> Void) {
        for id in ids {
            guard let index = workSets.firstIndex(where: { $0.id == id }) else { continue }
            mutate(&workSets[index])
        }
    }

    private func bindingPairReps(_ pair: WorkSetPair) -> Binding<String> {
        Binding(
            get: { pair.reps.map(String.init) ?? "" },
            set: { new in
                let value = Int(new)
                updateSets(matching: [pair.left.id, pair.right?.id].compactMap { $0 }) { set in
                    set.reps = value
                }
            }
        )
    }

    private func bindingPairHold(_ pair: WorkSetPair) -> Binding<String> {
        Binding(
            get: { pair.holdSeconds.map(String.init) ?? "" },
            set: { new in
                let value = Int(new)
                updateSets(matching: [pair.left.id, pair.right?.id].compactMap { $0 }) { set in
                    set.holdSeconds = value
                }
            }
        )
    }

    private func bindingPairLoad(_ pair: WorkSetPair, side: KneeSide?) -> Binding<String> {
        Binding(
            get: {
                let lbs: Double?
                switch side {
                case .left: lbs = pair.leftLoad
                case .right: lbs = pair.rightLoad
                case nil: lbs = pair.leftLoad ?? pair.rightLoad
                }
                return lbs.map(TrainingSession.formatLoad) ?? ""
            },
            set: { new in
                let trimmed = new.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
                let value = trimmed.isEmpty ? nil : Double(trimmed)
                switch side {
                case .left:
                    updateSets(matching: [pair.left.id]) { $0.loadLbs = value }
                case .right:
                    if let rightId = pair.right?.id {
                        updateSets(matching: [rightId]) { $0.loadLbs = value }
                    }
                case nil:
                    updateSets(matching: [pair.left.id, pair.right?.id].compactMap { $0 }) { $0.loadLbs = value }
                }
            }
        )
    }

    private func bindingWarmupReps(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard warmupSets.indices.contains(index), let r = warmupSets[index].reps else { return "" }
                return String(r)
            },
            set: { new in
                guard warmupSets.indices.contains(index) else { return }
                warmupSets[index].reps = Int(new)
            }
        )
    }

    private func bindingWarmupHold(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard warmupSets.indices.contains(index), let h = warmupSets[index].holdSeconds else { return "" }
                return String(h)
            },
            set: { new in
                guard warmupSets.indices.contains(index) else { return }
                warmupSets[index].holdSeconds = Int(new)
            }
        )
    }

    private func bindingWarmupLoad(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard warmupSets.indices.contains(index), let l = warmupSets[index].loadLbs else { return "" }
                return TrainingSession.formatLoad(l)
            },
            set: { new in
                guard warmupSets.indices.contains(index) else { return }
                let trimmed = new.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
                warmupSets[index].loadLbs = trimmed.isEmpty ? nil : Double(trimmed)
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
            } else {
                laterality = SessionSummary.inferredLaterality(workSets: workSets)
            }
            selectedPresetId = SessionPreset.forPhase(phase, primaryLoadID: primaryLoadID)
                .first { $0.sessionType == existing.sessionType && $0.tracksResistance }?.id
            refreshSpacing()
            return
        }

        if let settings = try? AppBootstrap.ensureSettings(context: modelContext) {
            phase = settings.currentPhase
        }
        laterality = SetLaterality(rawValue: storedLateralityRaw) ?? .bilateral
        switch focus {
        case .kneeResistance, .general:
            applyPreset(SessionPreset.preferred(for: phase, primaryLoadID: primaryLoadID))
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
                workSets = SessionSummary.makePair(
                    reps: 4,
                    loadLbs: nil,
                    holdSeconds: 30,
                    isWarmup: false
                )
            }
        } else {
            if warmupSets.isEmpty {
                warmupSets = [
                    ResistanceSet(reps: 2, loadLbs: nil, holdSeconds: 30, isWarmup: true)
                ]
            }
            if workSets.isEmpty {
                workSets = SessionSummary.makePair(
                    reps: 8,
                    loadLbs: nil,
                    holdSeconds: nil,
                    isWarmup: false
                )
            }
        }
    }

    private func syncWhatIDid() {
        let name: String
        if let id = selectedPresetId, let p = SessionPreset.all.first(where: { $0.id == id }) {
            name = p.label
        } else {
            name = PrimaryLoadCatalog.option(for: primaryLoadID).title
        }
        let wu = warmupSets.filter { $0.reps != nil || $0.loadLbs != nil || $0.holdSeconds != nil }
        let work = workSets.filter { $0.reps != nil || $0.loadLbs != nil || $0.holdSeconds != nil }
        if work.isEmpty && wu.isEmpty { return }
        // Don't clobber free-text history on edit unless it looks structured
        if isEditing, !whatIDid.isEmpty {
            let lower = whatIDid.lowercased()
            let structured = lower.contains("wu") || lower.contains("lb") || lower.contains("lbs") || lower.contains("×")
                || lower.contains("x") || lower.contains("set") || lower.contains("both")
            if !structured { return }
        }
        var parts = [name]
        if let compact = SessionSummary.compactResistance(wu + work) {
            parts.append(compact)
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
