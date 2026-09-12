import SwiftUI
import SwiftData

/// Today — one bright next action, three quiet entry rows, one streak line.
/// Sized to fit a single viewport: History holds the past, Today adds to it.
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
    @AppStorage("quoteTapOffset") private var quoteTapOffset = 0

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
        sessions.filter { calendar.isDate($0.date, inSameDayAs: today) }
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
        WorkoutStreak.evaluate(sessions: sessionSnaps, now: Date())
    }

    private var todayQuote: MotivationalQuote {
        MotivationalQuotes.quote(
            dayIndex: MotivationalQuotes.dailyIndex(on: today, calendar: calendar),
            tapOffset: quoteTapOffset
        )
    }

    private var hasMorningPain: Bool { todayCheckIn?.restingPainAM != nil }
    private var hasEveningPain: Bool { todayCheckIn?.dailyPainPM != nil }

    private var activePrimaryLoad: PrimaryLoadOption {
        settings?.primaryLoad ?? PrimaryLoadCatalog.defaultSelectable
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
                )
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                let action = nextAction
                VStack(alignment: .leading, spacing: 14) {
                    header
                    nextUpCard(action)
                    if let phaseAStatus {
                        phaseALine(phaseAStatus)
                    }
                    entryRows
                    streakLine
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
                    SessionEditor(targetDate: today, focus: .kneeResistance)
                }
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: Binding(
                get: { resolveTargetId != nil },
                set: { if !$0 { resolveTargetId = nil } }
            )) {
                if let id = resolveTargetId, let session = sessions.first(where: { $0.id == id }) {
                    Resolve24hSheet(session: session)
                }
            }
            .sheet(isPresented: Binding(
                get: { afterPainTargetId != nil },
                set: { if !$0 { afterPainTargetId = nil } }
            )) {
                if let id = afterPainTargetId, let session = sessions.first(where: { $0.id == id }) {
                    AfterPainSheet(session: session)
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

    private func nextUpCard(_ action: TodayNextAction) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(nextUpEyebrow(for: action).uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.quiet)

            Text(nextUpLine(for: action))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)

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
                    Label(activePrimaryLoad.logCTA, systemImage: InjuryCatalog.systemImage)
                }
                .buttonStyle(.primaryAction)

            case .logEvening:
                Button { showPM = true } label: {
                    Label("Log evening pain", systemImage: "moon.stars.fill")
                }
                .buttonStyle(.primaryAction)

            case .allDone:
                Label("Today is logged", systemImage: "checkmark.seal.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.vertical, 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface)
        )
    }

    private func nextUpEyebrow(for action: TodayNextAction) -> String {
        switch action {
        case .resolvePending: return "Needs your 24h call"
        case .allDone: return "Today"
        default: return "Next up"
        }
    }

    private func nextUpLine(for action: TodayNextAction) -> String {
        switch action {
        case .resolvePending(let id, let remaining):
            let session = sessions.first { $0.id == id }
            let title = session?.displayTitle ?? "Last session"
            let day = session?.date.formatted(date: .abbreviated, time: .omitted) ?? ""
            let more = remaining > 0 ? " · \(remaining) more waiting" : ""
            return "\(title) · \(day)\(more). Better, same, or worse the morning after?"
        case .logMorning:
            return "Resting pain before the day starts. It is the score the plan is judged on."
        case .logAfterPain(let id):
            let session = sessions.first { $0.id == id }
            return "\(session?.displayTitle ?? "Last session") · pain during \(session?.painDuring ?? 0). How does it feel now?"
        case .logSession:
            return activePrimaryLoad.homeObjective
        case .logEvening:
            return "Pain during today’s activities, plus steps."
        case .allDone:
            return "Morning, load, and evening are in. Judge it by tomorrow morning."
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
            entryRow(
                icon: InjuryCatalog.systemImage,
                title: activePrimaryLoad.title,
                value: sessionRowValue,
                logged: !todaySessions.isEmpty
            ) { showSession = true }
            Divider().overlay(AppTheme.quietStroke)
            entryRow(
                icon: "moon.stars",
                title: "Evening pain",
                value: eveningRowValue,
                logged: hasEveningPain
            ) { showPM = true }
        }
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface)
        )
    }

    private var sessionRowValue: String? {
        let count = todaySessions.count
        guard count > 0 else { return nil }
        if let pending = todaySessions.first(where: { !$0.hasLoggedPainAfter }) {
            return "During \(pending.painDuring) · after not logged"
        }
        return count == 1 ? "Logged" : "\(count) logged"
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
                Text(value ?? "Not logged")
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
        .accessibilityLabel("\(title), \(value ?? "not logged")")
        .accessibilityHint(logged ? "Edit" : "Log")
    }

    // MARK: Streak + one line

    private var streakLine: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: streak.current > 0 ? "flame.fill" : "link")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.quiet)
                    .accessibilityHidden(true)
                Text(WorkoutStreak.sessionWord(streak.current))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                Text("· \(streakSubtitle)")
                    .font(.caption)
                    .foregroundStyle(streak.miss == .twoMiss ? Color.orange : Color.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Button {
                quoteTapOffset += 1
                Haptics.light()
            } label: {
                Text(quoteLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Tap for another line")
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Hard session chain \(WorkoutStreak.sessionWord(streak.current)). \(streakSubtitle). \(todayQuote.text)"
        )
    }

    private var quoteLine: String {
        if let attribution = todayQuote.attribution {
            return "“\(todayQuote.text)” — \(attribution)"
        }
        return todayQuote.text
    }

    private var streakSubtitle: String {
        if let miss = WorkoutStreak.copy(for: streak.miss, lastChain: streak.lastChain) {
            return miss.title
        }
        if streak.best == 0 {
            return "hard-session chain, 48h window"
        }
        if streak.current == 0, streak.lastChain > 0 {
            return "last chain \(WorkoutStreak.sessionWord(streak.lastChain)) · best \(streak.best)"
        }
        if streak.best > streak.current {
            return "best \(WorkoutStreak.sessionWord(streak.best))"
        }
        return "keep the chain · 48 hours"
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

#Preview {
    HomeView()
        .environment(AppRouter())
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
