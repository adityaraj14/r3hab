import SwiftUI
import SwiftData

/// Today dashboard — checklist, pending 24h, session CTA.
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

    private var todayPending: [TrainingSession] {
        let ids = Set(PendingQueue.todayPending(sessions: sessionSnaps, now: Date(), calendar: calendar).map(\.id))
        return sessions.filter { ids.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
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

    private var missingAfterPain: [TrainingSession] {
        sessions
            .filter { !$0.hasLoggedPainAfter }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var pendingBadge: Int { overduePending.count }

    private var streak: WorkoutStreak.Snapshot {
        WorkoutStreak.evaluate(sessions: sessionSnaps, now: Date())
    }

    private var todayQuote: MotivationalQuote {
        MotivationalQuotes.quote(
            dayIndex: MotivationalQuotes.dailyIndex(on: today, calendar: calendar),
            tapOffset: quoteTapOffset
        )
    }

    private var hasMorningPain: Bool {
        todayCheckIn?.restingPainAM != nil
    }

    private var hasEveningPain: Bool {
        todayCheckIn?.dailyPainPM != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    streakAndQuote

                    if let miss = WorkoutStreak.copy(for: streak.miss, lastChain: streak.lastChain) {
                        missCue(miss)
                    }

                    if !overduePending.isEmpty {
                        pendingSection
                    }

                    if let phaseAStatus {
                        phaseABanner(phaseAStatus)
                    }

                    checklist

                    if !missingAfterPain.isEmpty {
                        afterPainSection
                    }

                    if !todayPending.isEmpty {
                        todaySessionPending
                    }

                    actions
                    guide
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsStubView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
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

    private var header: some View {
        HStack {
            PhaseChip(phase: settings?.currentPhase ?? .aFlareDeLoad)
            Spacer()
            if pendingBadge > 0 {
                Text("\(pendingBadge) pending")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.25), in: Capsule())
            }
            Text(today.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var streakAndQuote: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: streak.current > 0 ? "flame.fill" : "link")
                    .font(.title)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(WorkoutStreak.sessionWord(streak.current))
                        .font(.title.monospacedDigit().weight(.bold))
                        .foregroundStyle(Color.accentColor)
                    Text(streakSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            Button {
                quoteTapOffset += 1
                Haptics.light()
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todayQuote.text)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let attribution = todayQuote.attribution {
                        Text(attribution)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Tap for another line")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Hard session streak \(WorkoutStreak.sessionWord(streak.current)). \(streakSubtitle). \(todayQuote.text)"
        )
    }

    private var streakSubtitle: String {
        if streak.best == 0 {
            return "Hard rehab chain · tap the line for another"
        }
        if streak.current == 0, streak.lastChain > 0 {
            return "Last chain \(WorkoutStreak.sessionWord(streak.lastChain)) · best \(streak.best)"
        }
        if streak.best > streak.current {
            return "Best \(WorkoutStreak.sessionWord(streak.best))"
        }
        return "Keep the chain · 48 hours"
    }

    private func missCue(_ copy: (title: String, body: String)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(copy.title, systemImage: streak.miss == .twoMiss ? "exclamationmark.triangle.fill" : "link")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(streak.miss == .twoMiss ? Color.orange : Color.accentColor)
            Text(copy.body)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(streak.miss == .twoMiss ? Color.orange.opacity(0.12) : Color.accentColor.opacity(0.10))
        )
        .accessibilityElement(children: .combine)
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Needs 24h response", systemImage: "exclamationmark.bubble.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(overduePending, id: \.id) { session in
                pendingCard(session, early: false)
            }
        }
    }

    private var afterPainSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Log pain after", systemImage: "clock.badge.exclamationmark")
                .font(.headline)
                .foregroundStyle(Color.accentColor)

            ForEach(missingAfterPain, id: \.id) { session in
                VStack(alignment: .leading, spacing: 10) {
                    Text(session.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    if let resistance = session.resistanceSummary {
                        Text(resistance)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Text("During \(session.painDuring) · after not logged yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Button("Log after-pain") {
                        afterPainTargetId = session.id
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )
            }
        }
    }

    private var todaySessionPending: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today’s sessions")
                .font(.headline)
            ForEach(todayPending, id: \.id) { session in
                pendingCard(session, early: true)
            }
        }
    }

    private func pendingCard(_ session: TrainingSession, early: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(session.displayTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            if let resistance = session.resistanceSummary {
                Text(resistance)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text(pendingSubtitle(session))
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack {
                Button(early ? "Resolve early" : "Resolve") {
                    resolveTargetId = session.id
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                if session.snoozedUntil == nil {
                    Button("Snooze") { snooze(session) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }

                Button("Rest") { restConfirmId = session.id }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    private func pendingSubtitle(_ session: TrainingSession) -> String {
        "\(session.date.formatted(date: .abbreviated, time: .omitted)) · pain \(session.painDuring) during / \(session.displayPainAfter) after"
    }

    private func phaseABanner(_ status: PhaseAExitStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                status.isReadyToAdvance ? "Phase A exit looking good" : "Phase A progress",
                systemImage: status.isReadyToAdvance ? "checkmark.seal.fill" : "flag"
            )
            .font(.subheadline.weight(.semibold))
            Text(status.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(status.isReadyToAdvance ? Color.green.opacity(0.12) : Color(.secondarySystemBackground))
        )
    }

    private var checklist: some View {
        let c = todayCheckIn
        return VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.title3.weight(.semibold))
            checkRow(
                title: "Morning pain",
                done: c?.restingPainAM != nil,
                detail: morningPainDetail(c)
            )
            checkRow(
                title: "Evening pain",
                done: c?.dailyPainPM != nil,
                detail: eveningPainDetail(c)
            )
            checkRow(title: "Steps", done: c?.steps != nil, detail: c?.steps.map { "\($0)" })
        }
    }

    private func morningPainDetail(_ c: DailyCheckIn?) -> String? {
        c?.restingPainAM.map(String.init)
    }

    private func eveningPainDetail(_ c: DailyCheckIn?) -> String? {
        c?.dailyPainPM.map(String.init)
    }

    private func checkRow(title: String, done: Bool, detail: String?) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : Color.secondary)
            Text(title)
            Spacer()
            Text(detail ?? "Missing")
                .foregroundStyle(done ? Color.primary : Color.secondary)
                .font(.subheadline.monospacedDigit())
        }
        .padding(.vertical, 4)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button { showAM = true } label: {
                Label(hasMorningPain ? "Edit morning" : "Log morning", systemImage: "sun.max.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button { showPM = true } label: {
                Label(hasEveningPain ? "Edit evening" : "Log evening", systemImage: "moon.stars.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            VStack(alignment: .leading, spacing: 8) {
                Label("Patellar tendon", systemImage: "figure.strengthtraining.traditional")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PainChartColors.knee)
                Text(RehabTemplate.knee.objective(for: settings?.primaryLoad ?? PrimaryLoadCatalog.defaultSelectable))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button { showSession = true } label: {
                    Text(settings?.primaryLoad.logCTA ?? PrimaryLoadCatalog.defaultSelectable.logCTA)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Phase")
                .font(.headline)
            Text(PhaseGuideCopy.summary(
                for: settings?.currentPhase ?? .aFlareDeLoad,
                primaryLift: settings?.primaryLoad.title ?? PrimaryLoadCatalog.defaultSelectable.title
            ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(PhaseGuideCopy.redFlags)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 8)
    }

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

// TrainingSession already has `id: UUID` for Identifiable via SwiftData usage in ForEach

#Preview {
    HomeView()
        .environment(AppRouter())
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
