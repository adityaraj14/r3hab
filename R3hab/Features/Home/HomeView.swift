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
    @State private var showBackSession = false
    @State private var resolveTargetId: UUID?
    @State private var restConfirmId: UUID?

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

    private var metrics: [DailyMetricSnapshot] {
        checkIns.map {
            DailyMetricSnapshot(
                date: $0.date,
                restingPainAM: $0.restingPainAM,
                dailyPainPM: $0.dailyPainPM,
                lowerBackPainAM: $0.lowerBackPainAM,
                lowerBackPainPM: $0.lowerBackPainPM,
                steps: $0.steps
            )
        }
    }

    private var kneeAMSparkline: [DayValue] {
        ChartMetricBuilder.series(rows: metrics, metric: .restingAM, dayCount: 7)
    }

    private var backAMSparkline: [DayValue] {
        ChartMetricBuilder.series(rows: metrics, metric: .lowerBackAM, dayCount: 7)
    }

    private var hasKneeAMSparkline: Bool {
        kneeAMSparkline.contains { $0.value != nil }
    }

    private var hasBackAMSparkline: Bool {
        backAMSparkline.contains { $0.value != nil }
    }

    private var pendingBadge: Int { overduePending.count }

    private var hasMorningPain: Bool {
        todayCheckIn?.restingPainAM != nil || todayCheckIn?.lowerBackPainAM != nil
    }

    private var hasEveningPain: Bool {
        todayCheckIn?.dailyPainPM != nil || todayCheckIn?.lowerBackPainPM != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if !overduePending.isEmpty {
                        pendingSection
                    }

                    if let phaseAStatus {
                        phaseABanner(phaseAStatus)
                    }

                    checklist

                    if hasKneeAMSparkline || hasBackAMSparkline {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("AM pain · 7 days")
                                .font(.subheadline.weight(.semibold))

                            if hasKneeAMSparkline {
                                VStack(alignment: .leading, spacing: 6) {
                                    legendDot(color: PainChartColors.knee, label: "Knee")
                                    SparklineView(
                                        points: kneeAMSparkline,
                                        lineColor: PainChartColors.knee,
                                        height: 40
                                    )
                                }
                            }

                            if hasBackAMSparkline {
                                VStack(alignment: .leading, spacing: 6) {
                                    legendDot(color: PainChartColors.lowerBack, label: "Lower back")
                                    SparklineView(
                                        points: backAMSparkline,
                                        lineColor: PainChartColors.lowerBack,
                                        height: 40
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
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
                NavigationStack { DailyCheckInEditor(targetDate: today, focusPM: false) }
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showPM) {
                NavigationStack { DailyCheckInEditor(targetDate: today, focusPM: true) }
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showSession) {
                NavigationStack { SessionEditor(targetDate: today, focus: .kneeResistance) }
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showBackSession) {
                NavigationStack { SessionEditor(targetDate: today, focus: .lowerBackResistance) }
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
            Text(session.whatIDid)
                .font(.subheadline.weight(.semibold))
            Text(pendingSubtitle(session))
                .font(.caption)
                .foregroundStyle(.secondary)

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
        var parts = [
            session.date.formatted(date: .abbreviated, time: .omitted),
            "during \(session.painDuring) / after \(session.painAfter)"
        ]
        if let resistance = session.resistanceSummary {
            parts.append(resistance)
        }
        return parts.joined(separator: " · ")
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
                done: c?.restingPainAM != nil || c?.lowerBackPainAM != nil,
                detail: morningPainDetail(c)
            )
            checkRow(
                title: "Evening pain",
                done: c?.dailyPainPM != nil || c?.lowerBackPainPM != nil,
                detail: eveningPainDetail(c)
            )
            checkRow(title: "Steps", done: c?.steps != nil, detail: c?.steps.map { "\($0)" })
        }
    }

    private func morningPainDetail(_ c: DailyCheckIn?) -> String? {
        guard let c else { return nil }
        let knee = c.restingPainAM.map { "K\($0)" }
        let back = c.lowerBackPainAM.map { "B\($0)" }
        let parts = [knee, back].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func eveningPainDetail(_ c: DailyCheckIn?) -> String? {
        guard let c else { return nil }
        let knee = c.dailyPainPM.map { "K\($0)" }
        let back = c.lowerBackPainPM.map { "B\($0)" }
        let parts = [knee, back].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
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

            Button { showSession = true } label: {
                Label("Log knee training", systemImage: "figure.strengthtraining.traditional")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button { showBackSession = true } label: {
                Label("Log hip thrust (back)", systemImage: "figure.core.training")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var guide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This phase")
                .font(.headline)
            Text(PhaseGuideCopy.summary(for: settings?.currentPhase ?? .aFlareDeLoad))
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
