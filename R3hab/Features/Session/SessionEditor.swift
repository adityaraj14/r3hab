import SwiftUI
import SwiftData
import UIKit

/// Log or edit a training session. Historical rows own Delete and 24h here.
///
/// Holds only value state. When editing, the row is resolved by id through
/// `@Query` on every touch, so a sheet left open across a long background never
/// writes through a retained `TrainingSession`.
struct SessionEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsList: [AppSettings]
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var sessions: [TrainingSession]
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]

    var targetDate: Date = Date()
    /// Session to edit; `nil` logs a new one.
    var existingId: UUID?
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
    @State private var notes: String = ""
    @State private var errorMessage: String?
    @State private var errorDismissTask: Task<Void, Never>?
    @State private var spacingWarning: String?
    @State private var didLoad = false
    @State private var showMoreOptions = false
    @State private var whatIDidLocked = false
    @State private var response24hEdit: Response24h?
    @State private var confirmDelete = false

    private var calendar: Calendar { .current }
    private var settings: AppSettings? { settingsList.first }
    private var isEditing: Bool { existingId != nil }
    private var existing: TrainingSession? {
        guard let existingId else { return nil }
        return sessions.first { $0.id == existingId }
    }
    private var kind: SessionEditorKind {
        SessionEditorKind.classify(existingIsDraft: existing.map(\.isDraft))
    }

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

    /// New logs and drafts stay quiet. A completed edit opens More options.
    private var usesNewSessionChrome: Bool { kind.usesNewSessionChrome }

    var body: some View {
        Form {
            Section("Exercise") {
                Text(displayDate.formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                // Wrapping chips: a horizontal ScrollView inside a Form row
                // measured content at row width and clipped the overflow.
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(presetsForPhase) { preset in
                        exercisePill(preset, selected: selectedPresetId == preset.id)
                    }
                }
                .padding(.vertical, 2)
            }

            // Pain sits directly under Exercise so the required score is on
            // screen before the sets push it below the fold. Save still blocks
            // with the banner if it is empty.
            Section {
                PainScoreControl(title: "During (required)", value: $painDuring, allowsClear: false)
                if kind.shows24hResolution {
                    Picker("24h", selection: $response24hEdit) {
                        Text("Better").tag(Optional.some(Response24h.better))
                        Text("Same").tag(Optional.some(Response24h.same))
                        Text("Worse").tag(Optional.some(Response24h.worse))
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("24h resolution")
                }
            } header: {
                Text("Pain")
            } footer: {
                if kind.shows24hResolution {
                    Text("Next-morning tendon response. Changing Better, Same, or Worse overwrites the saved 24h.")
                } else {
                    Text("Pain during is required (0–10). We’ll remind you in about 30 minutes to log pain after.")
                }
            }

            if showsResistance {
                if showsWarmup {
                    warmupSection
                }

                workSetsSection
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }

            if showsLastSession, let last = lastSessionContext {
                Section {
                    Text(lastSessionLine(for: last))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(lastSessionLine(for: last))
                }
            }

            moreOptionsSection

            if let spacingWarning {
                Section {
                    Text(spacingWarning).font(.footnote).foregroundStyle(.orange)
                }
            }
        }
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            if kind.showsDelete {
                ToolbarItem(placement: .automatic) {
                    Button("Delete", role: .destructive) { confirmDelete = true }
                }
            }
            if kind.showsDraftSave {
                ToolbarItem(placement: .automatic) {
                    Button("Save draft") { persist(as: .draft) }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { persist(as: .finalize) }
                    .fontWeight(.semibold)
                    .tint(AppTheme.gold)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let errorMessage {
                FormErrorBanner(message: errorMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
        .onAppear(perform: load)
        .onChange(of: workSets) { _, _ in
            clearError()
            syncWhatIDid()
        }
        .onChange(of: warmupSets) { _, _ in
            clearError()
            syncWhatIDid()
        }
        .onChange(of: sessionType) { _, new in
            usesIsoHolds = (new == .isometrics)
            refreshSpacing()
        }
        .onChange(of: painDuring) { _, _ in clearError() }
        .confirmationDialog(
            "Delete this workout?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { deleteExisting() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private enum PersistKind {
        case draft
        case finalize
    }

    /// Selected: solid white fill, ink text. Unselected: faint fill, white text.
    /// Tinted `.bordered` read like a disabled gold button.
    private func exercisePill(_ preset: SessionPreset, selected: Bool) -> some View {
        Button {
            applyPreset(preset)
        } label: {
            // fixedSize keeps the label at its ideal width; FlowLayout wraps
            // chips to the next line instead of squeezing or clipping them.
            Text(preset.label)
                .font(.subheadline.weight(selected ? .bold : .medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(selected ? AppTheme.ink : Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(selected ? Color.white : AppTheme.quietFill)
                )
                .overlay(
                    Capsule().strokeBorder(selected ? Color.white : AppTheme.quietStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var lastSessionContext: TrainingSession? {
        sessions.first { $0.id != existingId && !$0.isDraft }
    }

    private var showsLastSession: Bool {
        usesNewSessionChrome
    }

    private func lastSessionLine(for last: TrainingSession) -> String {
        SessionSummary.lastSessionLine(
            whatIDid: last.whatIDid,
            sets: last.resistanceSets(),
            painDuring: last.painDuring
        )
    }

    private var moreOptionsSection: some View {
        Section {
            if showMoreOptions {
                Picker("Phase", selection: $phase) {
                    ForEach(RehabPhase.allCases) { p in
                        Text(p.title).tag(p)
                    }
                }
                .accessibilityLabel("Phase")
                Picker("Type", selection: $sessionType) {
                    ForEach(SessionType.allCases) { t in
                        Text(t.title).tag(t)
                    }
                }
                .accessibilityLabel("Type")
                TextField("What I did", text: whatIDidBinding, axis: .vertical)
                    .lineLimit(2...4)
                    .accessibilityLabel("What I did")
                Button("Show less") { showMoreOptions = false }
            } else {
                Button("More options") { showMoreOptions = true }
                    .accessibilityHint("Phase, type, and what I did")
            }
        } footer: {
            if !showMoreOptions {
                Text("Phase \(phase.shortTitle) · \(sessionType.title)")
            }
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

    private var whatIDidBinding: Binding<String> {
        Binding(
            get: { whatIDid },
            set: { newValue in
                whatIDid = newValue
                whatIDidLocked = true
                clearError()
            }
        )
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
            Button {
                lateralityBinding.wrappedValue = laterality == .bilateral ? .unilateral : .bilateral
            } label: {
                Text(laterality == .bilateral ? "Split L/R loads" : "Use one load")
            }
            .accessibilityLabel(laterality == .bilateral ? "Split left and right loads" : "Use one load for both legs")
            .accessibilityValue(laterality.title)

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
            if laterality == .unilateral {
                Text("Left and right loads can differ. One 24h resolve for the session.")
            }
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

    /// Caption carries the label; the field placeholder is a neutral dash so
    /// "Load (lbs)" is not printed twice per column.
    private func labeledIntField(title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField("—", text: value)
                .keyboardType(.numberPad)
                .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeledLoadField(title: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField("—", text: value)
                .keyboardType(.decimalPad)
                .accessibilityLabel(title)
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
            painDuring = PainScore.optional(existing.painDuring)
            response24hEdit = Session24hResolution.pickerSelection(stored: existing.response24h)
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
            whatIDidLocked = !existing.whatIDid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !SessionSummary.looksStructuredWhatIDid(existing.whatIDid)
            showMoreOptions = !existing.isDraft
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
        whatIDidLocked = false
        if !preset.whatIDid.isEmpty {
            whatIDid = preset.whatIDid
        }
        if !isEditing {
            workSets = []
            warmupSets = []
        }
        if preset.tracksResistance {
            seedDefaultSets()
        }
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
            return
        }

        let title: String
        if let id = selectedPresetId, let preset = SessionPreset.all.first(where: { $0.id == id }) {
            title = preset.label
        } else {
            title = PrimaryLoadCatalog.option(for: primaryLoadID).title
        }
        let prescription = ProgressionEngine.today(
            sessions: sessions.filter { $0.id != existingId }.map(\.snapshot),
            checkIns: checkIns.map(\.snapshot),
            primaryLoadTitle: title,
            asOf: Date(),
            calendar: calendar
        )
        laterality = prescription.laterality
        storedLateralityRaw = prescription.laterality.rawValue
        if warmupSets.isEmpty {
            warmupSets = [SessionPrefill.warmupSet(loadLbs: prescription.target.loadLbs)]
        }
        if workSets.isEmpty {
            workSets = SessionPrefill.workSets(
                from: prescription.target,
                laterality: prescription.laterality
            )
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
        if whatIDidLocked { return }
        if isEditing, !whatIDid.isEmpty, !SessionSummary.looksStructuredWhatIDid(whatIDid) {
            return
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

    private func persist(as persistKind: PersistKind) {
        let shouldWrite24h = kind.shows24hResolution
        clearError()

        var wu = warmupSets.map { var s = $0; s.isWarmup = true; return s }
        var work = workSets.map { var s = $0; s.isWarmup = false; return s }
        wu = wu.filter { $0.reps != nil || $0.loadLbs != nil || $0.holdSeconds != nil }
        work = work.filter { $0.reps != nil || $0.loadLbs != nil || $0.holdSeconds != nil }
        if persistKind == .finalize {
            work = ProgressionEngine.applySessionPain(painDuring, to: work)
        }
        let allSets = wu + work
        let text = whatIDid.trimmingCharacters(in: .whitespacesAndNewlines)

        switch persistKind {
        case .finalize:
            if let issue = SessionSaveValidation.validate(
                painDuring: painDuring,
                painAfter: existing?.loggedPainAfter,
                whatIDid: whatIDid,
                sets: allSets
            ) {
                presentError(issue.message)
                return
            }
            guard painDuring != nil else {
                presentError(SessionSaveIssue.missingPainDuring.message)
                return
            }
        case .draft:
            if !SessionDraft.isWorthSaving(painDuring: painDuring, notes: notes, sets: allSets) {
                presentError(SessionDraft.emptyMessage)
                return
            }
        }

        let storedDuring = painDuring ?? PainScore.notLogged
        let storedAfter = resolvedPainAfter()
        let reuseId = existingId ?? draftReuseID(for: persistKind)
        let existingRow = reuseId.flatMap { id in sessions.first { $0.id == id } }
        if existingId != nil && existingRow == nil {
            presentError("This session is no longer available.")
            return
        }

        let wasDraft = existingRow?.isDraft == true
        let row: TrainingSession
        let isInsert: Bool
        if let existingRow {
            row = existingRow
            isInsert = false
            row.phase = phase
            row.sessionType = sessionType
            row.whatIDid = text
            row.painDuring = storedDuring
            row.painAfter = storedAfter
            row.notes = notes
            row.setResistanceSets(allSets)
            row.updatedAt = Date()
        } else {
            row = TrainingSession(
                date: targetDate,
                phase: phase,
                sessionType: sessionType,
                whatIDid: text,
                painDuring: storedDuring,
                painAfter: storedAfter,
                resistanceSets: allSets,
                calendar: calendar
            )
            row.notes = notes
            modelContext.insert(row)
            isInsert = true
        }
        row.isDraft = persistKind == .draft
        let cancelPending24h = shouldWrite24h && apply24hIfNeeded(to: row)

        do {
            try modelContext.save()
            if cancelPending24h {
                NotificationScheduler.cancelPending(sessionId: row.id)
            }
            applyNotifications(for: row, kind: persistKind, wasInsert: isInsert, wasDraft: wasDraft)
            Haptics.light()
            dismiss()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func draftReuseID(for kind: PersistKind) -> UUID? {
        guard kind == .draft else { return nil }
        return SessionDraft.openDraftID(
            in: sessions.map(\.snapshot),
            on: displayDate,
            preferring: sessionType,
            calendar: calendar
        )
    }

    private func applyNotifications(
        for session: TrainingSession,
        kind: PersistKind,
        wasInsert: Bool,
        wasDraft: Bool
    ) {
        if kind == .draft {
            NotificationScheduler.cancelSessionNotifications(sessionId: session.id)
            return
        }
        if session.hasLoggedPainAfter {
            NotificationScheduler.cancelPainAfter(sessionId: session.id)
        }
        guard wasInsert || wasDraft else { return }
        guard let settings, settings.notificationsEnabled else { return }
        NotificationScheduler.schedulePending(
            sessionId: session.id,
            sessionDate: session.date,
            snoozedUntil: nil,
            amHour: settings.amReminderHour,
            amMinute: settings.amReminderMinute
        )
        if !session.hasLoggedPainAfter {
            NotificationScheduler.schedulePainAfter(
                sessionId: session.id,
                createdAt: session.createdAt
            )
        }
    }

    private func apply24hIfNeeded(to row: TrainingSession) -> Bool {
        let priors = DecisionSuggester.priorsForSuggestion(
            current: row.snapshot,
            all: sessions.map(\.snapshot)
        )
        let suggested = response24hEdit.flatMap {
            DecisionSuggester.suggest(response: $0, recentResolvedNonRest: priors)
        }
        let write = Session24hResolution.write(
            selected: response24hEdit,
            storedResponse: row.response24h,
            storedDecision: row.decision,
            storedResolvedAt: row.resolvedAt,
            storedSnoozedUntil: row.snoozedUntil,
            suggestedDecision: suggested,
            now: Date()
        )
        row.response24h = write.response
        row.decision = write.decision
        row.resolvedAt = write.resolvedAt
        row.snoozedUntil = write.snoozedUntil
        return write.cancelsPendingNotification
    }

    private func deleteExisting() {
        guard kind.showsDelete, let row = existing else { return }
        NotificationScheduler.cancelSessionNotifications(sessionId: row.id)
        modelContext.delete(row)
        do {
            try modelContext.save()
            Haptics.warning()
            dismiss()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func resolvedPainAfter() -> Int {
        existing?.painAfter ?? PainScore.notLogged
    }

    private func presentError(_ message: String) {
        errorMessage = message
        errorDismissTask?.cancel()
        errorDismissTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled {
                await MainActor.run { errorMessage = nil }
            }
        }
    }

    private func clearError() {
        errorMessage = nil
        errorDismissTask?.cancel()
    }
}

#Preview {
    NavigationStack {
        SessionEditor(focus: .kneeResistance)
    }
    .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
    .preferredColorScheme(.dark)
}
