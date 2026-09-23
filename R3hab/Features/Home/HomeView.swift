import SwiftUI
import SwiftData

/// Today — the day's line large, the hard/rest chain beside the count,
/// one bright next action, three quiet entry rows.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \TrainingSession.createdAt, order: .reverse) private var sessions: [TrainingSession]
    @Query private var settingsList: [AppSettings]

    @State private var showAM = false
    @State private var showPM = false
    @State private var showSession = false
    @State private var resolveTargetId: UUID?
    @State private var afterPainTargetId: UUID?
    @State private var restConfirmId: UUID?
    /// Bumped to the live count only on the save that extends the chain, so the
    /// new bead fills once instead of every time Today appears.
    @State private var popToken = 0
    /// True only after a non-empty session query has been seen, so the empty
    /// first frame cannot zero the latch and then celebrate the real chain.
    @State private var ritualsSawSessions = false
    @AppStorage("r3hab.celebratedStreak") private var celebratedStreak = 0
    @AppStorage("r3hab.closedDayKey") private var closedDayKey = ""

    private var calendar: Calendar { .current }
    private var today: Date { calendar.startOfDay(for: Date()) }
    private var settings: AppSettings? { settingsList.first }

    private var todayCheckIn: DailyCheckIn? {
        let key = DailyCheckIn.dayKey(for: today)
        return checkIns.first { $0.dayKey == key }
    }

    private var sessionSnaps: [TrainingSessionSnapshot] {
        sessions.map(\.snapshot)
    }

    private var overduePending: [TrainingSession] {
        let ids = Set(PendingQueue.overdue(sessions: sessionSnaps, now: Date(), calendar: calendar).map(\.id))
        return sessions.filter { ids.contains($0.id) }
            .sorted { a, b in
                if a.date != b.date { return a.date < b.date }
                return a.createdAt < b.createdAt
            }
    }

    private var todaySessions: [TrainingSession] {
        sessions.filter { !$0.isDraft && calendar.isDate($0.date, inSameDayAs: today) }
    }

    private var todayDraftId: UUID? {
        let preferredType = SessionPreset.preferred(
            for: settings?.currentPhase ?? .aFlareDeLoad,
            primaryLoadID: settings?.primaryLoadID ?? PrimaryLoadCatalog.defaultID
        ).sessionType
        return SessionDraft.openDraftID(
            in: sessions.map(\.snapshot),
            on: today,
            preferring: preferredType,
            calendar: calendar
        )
    }

    private var phaseAStatus: PhaseAExitStatus? {
        guard let settings, settings.currentPhase == .aFlareDeLoad else { return nil }
        return PhaseAExitEvaluator.evaluate(
            checkIns: checkIns.map(\.snapshot),
            settings: settings.phaseSnapshot,
            today: Date(),
            calendar: calendar
        )
    }

    private var streak: WorkoutStreak.Snapshot {
        WorkoutStreak.evaluate(sessions: sessionSnaps, now: Date(), calendar: calendar)
    }

    private var hasMorningPain: Bool { todayCheckIn?.restingPainAM != nil }
    private var hasEveningPain: Bool { todayCheckIn?.dailyPainPM != nil }

    private var activePrimaryLoad: PrimaryLoadOption {
        settings?.primaryLoad ?? PrimaryLoadCatalog.defaultSelectable
    }

    private var todayProgression: ProgressionResult {
        ProgressionEngine.today(
            sessions: sessionSnaps,
            primaryLoadTitle: activePrimaryLoad.title,
            asOf: Date(),
            calendar: calendar
        )
    }

    private var nextAction: TodayNextAction {
        let now = Date()
        return TodayPlanner.nextAction(
            TodayPlannerInput(
                hasMorningPain: hasMorningPain,
                hasEveningPain: hasEveningPain,
                overduePending: overduePending.map(\.id),
                missingAfterPain: TodayPlanner.recentMissingAfterPain(sessions: sessionSnaps, now: now),
                trainedToday: !todaySessions.isEmpty,
                isEvening: TodayPlanner.isEvening(
                    now: now,
                    pmReminderHour: settings?.pmReminderHour ?? 18,
                    pmReminderMinute: settings?.pmReminderMinute ?? 30,
                    calendar: calendar
                ),
                isRestDay: streak.isRestDay
            )
        )
    }

    private var sessionEntry: TodaySessionEntry {
        TodaySessionEntry.resolve(
            isRestDay: streak.isRestDay,
            hasDraft: todayDraftId != nil,
            todaySessions: todaySessions.map(\.snapshot),
            target: todayProgression.target,
            laterality: todayProgression.laterality
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                let action = nextAction
                VStack(alignment: .leading, spacing: 14) {
                    streakCard
                    header
                    nextUpCard(action)
                    if let phaseAStatus {
                        phaseALine(phaseAStatus)
                    }
                    entryRows
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .appCanvas()
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsStubView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .tint(AppTheme.quiet)
                }
            }
            .sheet(isPresented: $showAM) {
                NavigationStack { DailyCheckInEditor(targetDate: today, focus: .morning) }
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showPM) {
                NavigationStack { DailyCheckInEditor(targetDate: today, focus: .evening) }
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showSession) {
                NavigationStack {
                    SessionEditor(
                        targetDate: today,
                        existingId: todayDraftId,
                        focus: .kneeResistance
                    )
                }
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: Binding(
                get: { resolveTargetId != nil },
                set: { if !$0 { resolveTargetId = nil } }
            )) {
                if let id = resolveTargetId {
                    Resolve24hSheet(sessionId: id)
                }
            }
            .sheet(isPresented: Binding(
                get: { afterPainTargetId != nil },
                set: { if !$0 { afterPainTargetId = nil } }
            )) {
                if let id = afterPainTargetId {
                    AfterPainSheet(sessionId: id)
                }
            }
            .confirmationDialog(
                "Close without 24h judgment?",
                isPresented: Binding(
                    get: { restConfirmId != nil },
                    set: { if !$0 { restConfirmId = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Mark Rest", role: .destructive) {
                    if let id = restConfirmId, let s = sessions.first(where: { $0.id == id }) {
                        markRest(s)
                    }
                    restConfirmId = nil
                }
                Button("Cancel", role: .cancel) { restConfirmId = nil }
            }
            .task {
                _ = try? AppBootstrap.ensureSettings(context: modelContext)
            }
            .onAppear(perform: noteRituals)
            .onChange(of: streak.current) { _, _ in noteRituals() }
            .onChange(of: nextAction) { _, _ in noteRituals() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            NavigationLink {
                PhaseGuideView()
            } label: {
                PhaseChip(phase: settings?.currentPhase ?? .aFlareDeLoad)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the phase guide")
            Spacer()
            Text(today.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Next up — the only gold on the screen

    /// Eyebrow, the stance, then the one action. The dose button carries
    /// the stance with it. Other actions keep the same line on the card.
    private func nextUpCard(_ action: TodayNextAction) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(nextUpEyebrow(for: action).uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.quiet)

            if !actionShowsDose(action) {
                stanceLine(todayProgression, onGold: false)
            }

            switch action {
            case .resolvePending(let id, _):
                Button {
                    resolveTargetId = id
                } label: {
                    Label("Resolve 24h response", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.primaryAction)

                if let session = sessions.first(where: { $0.id == id }) {
                    HStack(spacing: 8) {
                        if session.snoozedUntil == nil {
                            Button("Snooze to morning") { snooze(session) }
                                .buttonStyle(.quietCompact)
                        }
                        Button("Mark rest") { restConfirmId = session.id }
                            .buttonStyle(.quietCompact)
                    }
                }

            case .logMorning:
                Button { showAM = true } label: {
                    Label("Log morning pain", systemImage: "sun.max.fill")
                }
                .buttonStyle(.primaryAction)

            case .logAfterPain(let id):
                Button {
                    afterPainTargetId = id
                } label: {
                    Label("Log pain after", systemImage: "bolt.heart.fill")
                }
                .buttonStyle(.primaryAction)

            case .logSession:
                Button { showSession = true } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        stanceLine(todayProgression, onGold: true)
                        Label(activePrimaryLoad.logCTA, systemImage: InjuryCatalog.systemImage)
                        Text(todayProgression.target.todayLine)
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.primaryAction)
                .accessibilityLabel("\(todayProgression.stance.label). \(todayProgression.reason). \(activePrimaryLoad.logCTA). \(todayProgression.target.todayLine)")

            case .logEvening:
                Button { showPM = true } label: {
                    Label("Log evening pain", systemImage: "moon.stars.fill")
                }
                .buttonStyle(.primaryAction)

            case .restDay:
                VStack(alignment: .leading, spacing: 4) {
                    Label("Rest day", systemImage: "leaf.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("The chain holds. Nothing to load today.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)

            case .allDone:
                Label("Today is logged", systemImage: "checkmark.seal.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.top, 6)
                Text(TodayPlanner.allDoneLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let pendingID = todayProgression.pendingResolveID, !actionResolves24h(action) {
                Button("Resolve 24h response") { resolveTargetId = pendingID }
                    .buttonStyle(.quietCompact)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .posterCard()
    }

    @ViewBuilder
    private func stanceLine(_ result: ProgressionResult, onGold: Bool) -> some View {
        let ink = onGold ? AppTheme.ink : AppTheme.ivory
        let reason = onGold ? AppTheme.ink.opacity(0.8) : AppTheme.quiet
        VStack(alignment: .leading, spacing: 4) {
            Text(result.stance.label)
                .font(.caption.weight(.bold))
                .foregroundStyle(ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(onGold ? AppTheme.ink.opacity(0.12) : AppTheme.quietFill, in: Capsule())
                .overlay {
                    if !onGold {
                        Capsule().strokeBorder(AppTheme.quietStroke, lineWidth: 1)
                    }
                }
            Text(result.reason)
                .font(.subheadline)
                .foregroundStyle(reason)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.stance.label). \(result.reason)")
    }

    private func actionShowsDose(_ action: TodayNextAction) -> Bool {
        if case .logSession = action { return true }
        return false
    }

    private func actionResolves24h(_ action: TodayNextAction) -> Bool {
        if case .resolvePending = action { return true }
        return false
    }

    private func nextUpEyebrow(for action: TodayNextAction) -> String {
        switch action {
        case .resolvePending: return "Needs your 24h call"
        case .restDay: return "Rest day"
        case .allDone: return "Today"
        default: return "Next up"
        }
    }

    // MARK: Phase A (only while in Phase A)

    private func phaseALine(_ status: PhaseAExitStatus) -> some View {
        Label(status.message, systemImage: status.isReadyToAdvance ? "checkmark.seal.fill" : "flag")
            .font(.footnote)
            .foregroundStyle(status.isReadyToAdvance ? Color.green : Color.secondary)
            .lineLimit(2)
            .padding(.horizontal, 4)
            .accessibilityLabel("Phase A exit. \(status.message)")
    }

    // MARK: Entry rows — quiet, one tap each

    private var entryRows: some View {
        VStack(spacing: 0) {
            entryRow(
                icon: "sun.max",
                title: "Morning pain",
                value: todayCheckIn?.restingPainAM.map(String.init),
                logged: hasMorningPain
            ) { showAM = true }
            Divider().overlay(AppTheme.quietStroke)
            sessionEntryRow
            Divider().overlay(AppTheme.quietStroke)
            entryRow(
                icon: "moon.stars",
                title: "Evening pain",
                value: eveningRowValue,
                logged: hasEveningPain
            ) { showPM = true }
        }
        .padding(.horizontal, 16)
        .posterCard()
    }

    private var sessionEntryRow: some View {
        let entry = sessionEntry
        let isRest = entry == .rest
        let title = isRest ? "Rest day" : activePrimaryLoad.title
        let placeholder = isRest ? "Optional" : "Not logged"
        let logged = !todaySessions.isEmpty
        let trailing = sessionTrailingValue(entry)
        let lines = sessionDetailLines(entry)
        return Button {
            showSession = true
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: logged ? "checkmark.circle.fill" : (isRest ? "leaf" : InjuryCatalog.systemImage))
                    .font(.body)
                    .foregroundStyle(logged ? Color.green : AppTheme.quiet)
                    .frame(width: 22)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        if lines.isEmpty {
                            Text(trailing ?? placeholder)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(trailing == nil ? Color.secondary.opacity(0.7) : Color.secondary)
                                .lineLimit(1)
                        }
                    }
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if let status = entry.loggedStatus, !lines.isEmpty {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sessionAccessibilityLabel(title: title, trailing: trailing, placeholder: placeholder, lines: lines, status: entry.loggedStatus))
        .accessibilityHint(logged ? "Edit" : "Log")
    }

    private func sessionTrailingValue(_ entry: TodaySessionEntry) -> String? {
        switch entry {
        case .resumeDraft:
            return "Resume draft"
        case .logged(let load, let status) where !load.hasLines:
            return status
        case .rest, .target, .logged:
            return nil
        }
    }

    private func sessionDetailLines(_ entry: TodaySessionEntry) -> [String] {
        guard let load = entry.load, load.hasLines else { return [] }
        return [load.warmupNote].compactMap { $0 } + load.workLines
    }

    private func sessionAccessibilityLabel(
        title: String,
        trailing: String?,
        placeholder: String,
        lines: [String],
        status: String?
    ) -> String {
        var parts = [title]
        parts.append(contentsOf: lines)
        if lines.isEmpty {
            parts.append(trailing ?? placeholder.lowercased())
        } else if let status {
            parts.append(status)
        }
        return parts.joined(separator: ", ")
    }

    private var eveningRowValue: String? {
        guard let c = todayCheckIn else { return nil }
        let pain = c.dailyPainPM.map(String.init)
        let steps = c.steps.map { "\($0.formatted()) steps" }
        switch (pain, steps) {
        case let (p?, s?): return "\(p) · \(s)"
        case let (p?, nil): return p
        case let (nil, s?): return s
        case (nil, nil): return nil
        }
    }

    private func entryRow(
        icon: String,
        title: String,
        value: String?,
        placeholder: String = "Not logged",
        logged: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: logged ? "checkmark.circle.fill" : icon)
                    .font(.body)
                    .foregroundStyle(logged ? Color.green : AppTheme.quiet)
                    .frame(width: 22)
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(value ?? placeholder)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(value == nil ? Color.secondary.opacity(0.7) : Color.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(value ?? placeholder.lowercased())")
        .accessibilityHint(logged ? "Edit" : "Log")
    }

    // MARK: Streak — the day's line, then the chain

    /// Quote and count share the card. The line stays a serif; the number is
    /// the large counter. The chain sits under the quote. Nothing is tappable.
    private var streakCard: some View {
        let picture = WorkoutStreak.picture(sessions: sessionSnaps, now: Date(), calendar: calendar)
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("“\(todayQuote.text)”")
                    .font(.system(.title2, design: .serif))
                    .foregroundStyle(AppTheme.ivory)
                    .fixedSize(horizontal: false, vertical: true)
                if let attribution = todayQuote.attribution {
                    Text(attribution)
                        .font(.caption)
                        .foregroundStyle(AppTheme.quiet)
                }
                if picture.beads.isEmpty {
                    Image(systemName: "link")
                        .font(.body)
                        .foregroundStyle(AppTheme.quiet)
                        .accessibilityHidden(true)
                } else {
                    ChainBeads(
                        beads: picture.beads,
                        freshIndex: picture.freshIndex,
                        popToken: popToken,
                        liveCount: streak.current
                    )
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(streak.current)")
                    .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(AppTheme.gold)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(streak.current == 1 ? "session" : "sessions")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.quiet)
                if let streakStatus {
                    Text(streakStatus)
                        .font(.caption)
                        .foregroundStyle(streak.miss == .twoMiss ? AppTheme.gold : AppTheme.quiet)
                        .lineLimit(1)
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .posterCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("today-poster")
        .accessibilityLabel(streakAccessibilityLabel)
    }

    private var streakAccessibilityLabel: String {
        var parts = ["Streak \(WorkoutStreak.sessionWord(streak.current))"]
        if let streakStatus {
            parts.append(streakStatus)
        }
        parts.append(todayQuote.text)
        return parts.joined(separator: ". ")
    }

    /// One line per calendar day; changes overnight, never on tap.
    private var todayQuote: MotivationalQuote {
        MotivationalQuotes.quote(on: today, calendar: calendar)
    }

    private var todayKey: String {
        let parts = calendar.dateComponents([.year, .month, .day], from: today)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    /// Success only when the chain grows, or when Today first reaches all-done.
    /// Opening an already-finished day does not buzz again.
    private func noteRituals() {
        // @Query is empty for a frame before SwiftData delivers rows. Writing
        // 0 into the latch makes the real count look like a chain that just grew.
        if sessions.isEmpty {
            if ritualsSawSessions {
                celebratedStreak = 0
            }
            return
        }
        ritualsSawSessions = true

        let snap = streak
        var celebratedChain = false
        if snap.daysSinceLastHard == 0, snap.current > celebratedStreak {
            celebratedStreak = snap.current
            popToken = snap.current
            Haptics.success()
            celebratedChain = true
        } else if celebratedStreak != snap.current {
            celebratedStreak = snap.current
        }

        if case .allDone = nextAction {
            let key = todayKey
            if closedDayKey != key {
                closedDayKey = key
                if !celebratedChain {
                    Haptics.success()
                }
            }
        }
    }

    /// Miss state first (due today / missed), then the off day, then the
    /// record when it beats the live count. Nothing when there is nothing to say.
    private var streakStatus: String? {
        if let status = WorkoutStreak.statusLabel(for: streak.miss) {
            return status
        }
        if streak.isRestDay {
            return "Rest day"
        }
        if streak.best > streak.current {
            return "Best \(WorkoutStreak.sessionWord(streak.best))"
        }
        return nil
    }

    // MARK: Actions

    private func snooze(_ session: TrainingSession) {
        guard session.snoozedUntil == nil else { return }
        let amH = settings?.amReminderHour ?? 8
        let amM = settings?.amReminderMinute ?? 0
        let until = PendingQueue.nextMorningReminder(
            after: Date(),
            amHour: amH,
            amMinute: amM
        )
        session.snoozedUntil = until
        session.snoozeUsed = true
        session.updatedAt = Date()
        try? modelContext.save()
        NotificationScheduler.cancelPending(sessionId: session.id)
        if settings?.notificationsEnabled == true {
            NotificationScheduler.schedulePending(
                sessionId: session.id,
                sessionDate: session.date,
                snoozedUntil: until,
                amHour: amH,
                amMinute: amM
            )
        }
        Haptics.light()
        router.requestNotificationSync()
    }

    private func markRest(_ session: TrainingSession) {
        session.response24h = .notApplicable
        session.decision = .rest
        session.resolvedAt = Date()
        session.snoozedUntil = nil
        session.updatedAt = Date()
        try? modelContext.save()
        NotificationScheduler.cancelPending(sessionId: session.id)
        Haptics.light()
        router.requestNotificationSync()
    }
}

/// Hard beads are filled in the pop color. Rest days are hollow and neutral.
/// The due day is a hollow bead in the pop — the open slot, not a miss.
private struct ChainBeads: View {
    var beads: [WorkoutStreak.ChainBead]
    var freshIndex: Int?
    var popToken: Int
    var liveCount: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(beads.enumerated()), id: \.offset) { index, bead in
                beadGlyph(
                    bead,
                    pops: bead == .hard && index == freshIndex && popToken == liveCount && liveCount > 0
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func beadGlyph(_ bead: WorkoutStreak.ChainBead, pops: Bool) -> some View {
        let side: CGFloat = bead == .rest ? 8 : 13
        return Circle()
            .fill(fill(bead))
            .overlay(Circle().strokeBorder(stroke(bead), lineWidth: bead == .hard ? 0 : 1.5))
            .frame(width: side, height: side)
            .modifier(PopIn(active: pops))
    }

    private func fill(_ bead: WorkoutStreak.ChainBead) -> Color {
        switch bead {
        case .hard: return AppTheme.gold
        case .rest, .due: return .clear
        }
    }

    private func stroke(_ bead: WorkoutStreak.ChainBead) -> Color {
        switch bead {
        case .hard: return .clear
        case .rest: return AppTheme.rest
        case .due: return AppTheme.gold
        }
    }
}

private struct PopIn: ViewModifier {
    var active: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && !shown ? 0.2 : 1)
            .onAppear {
                guard active else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.55)) {
                    shown = true
                }
            }
            .onChange(of: active) { _, isActive in
                guard isActive else { return }
                shown = false
                withAnimation(.spring(response: 0.42, dampingFraction: 0.55)) {
                    shown = true
                }
            }
    }
}

#Preview {
    HomeView()
        .environment(AppRouter())
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
