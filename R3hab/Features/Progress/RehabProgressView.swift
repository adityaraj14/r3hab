import SwiftUI
import SwiftData

/// Progress tab — pain vs volume, 24h outcomes, consistency.
struct RehabProgressView: View {
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]
    @Query private var settingsList: [AppSettings]

    @State private var range: ProgressDayRange = .days7
    @AppStorage(ProgressChartStyle.storageKey) private var chartStyleRaw = ProgressChartStyle.ribbon.rawValue

    private var settings: AppSettings? { settingsList.first }

    private var metrics: [DailyMetricSnapshot] {
        checkIns.map {
            DailyMetricSnapshot(
                date: $0.date,
                restingPainAM: $0.restingPainAM,
                dailyPainPM: $0.dailyPainPM,
                steps: $0.steps
            )
        }
    }

    private var finalizedSessions: [TrainingSession] {
        sessions.filter { !$0.isDraft }
    }

    private var sessionPains: [SessionPainSnapshot] {
        finalizedSessions.map {
            SessionPainSnapshot(date: $0.date, painDuring: $0.painDuring, painAfter: $0.painAfter)
        }
    }

    private var sessionOutcomes: [SessionOutcomeSnapshot] {
        finalizedSessions.map {
            SessionOutcomeSnapshot(date: $0.date, createdAt: $0.createdAt, response24h: $0.response24h)
        }
    }

    private var windowDays: Int {
        range.dayCount(
            checkInDates: checkIns.map(\.date),
            sessionDates: finalizedSessions.map(\.date)
        )
    }

    private var explorePoints: [DayExplorePoint] {
        ChartMetricBuilder.explorePoints(
            checkIns: metrics,
            sessions: finalizedSessions.map { session in
                SessionLoadSnapshot(
                    date: session.date,
                    createdAt: session.createdAt,
                    volume: session.chartVolume,
                    loadLbs: workingLoad(session),
                    walkOnly: walkOnly(session)
                )
            },
            dayCount: windowDays,
            sessionPains: sessionPains
        )
    }

    private var outcomeMix: OutcomeMix {
        ChartMetricBuilder.outcomeMix(
            sessions: sessionOutcomes,
            dayCount: windowDays
        )
    }

    private var consistency: ConsistencySummary {
        ChartMetricBuilder.consistency(
            checkIns: metrics,
            sessions: sessionOutcomes,
            dayCount: windowDays
        )
    }

    private var interpretation: ProgressWindowReadout {
        ProgressInterpretation.classify(points: explorePoints)
    }

    /// Phase B stretch: clean sessions since phase change while in B (REQ-FUNC-017).
    private var phaseBCleanCount: Int? {
        guard let settings, settings.currentPhase == .bIsometrics else { return nil }
        return finalizedSessions.filter {
            $0.date >= settings.phaseChangedAt
                && $0.phase == .bIsometrics
                && ($0.response24h == .better || $0.response24h == .same)
        }.count
    }

    private var hasAnyData: Bool {
        !checkIns.isEmpty || !finalizedSessions.isEmpty
    }

    private var primaryLoad: PrimaryLoadOption {
        settings?.primaryLoad ?? PrimaryLoadCatalog.defaultSelectable
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !hasAnyData {
                        ContentUnavailableView(
                            "No pain logs or sessions yet",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text(progressEmptyDescription)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        interpretationCard(interpretation)

                        Picker("Range", selection: $range) {
                            ForEach(ProgressDayRange.allCases) { r in
                                Text(r.pickerTitle).tag(r)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Chart range")

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Pain, load, and steps")
                                .font(.headline)
                            Text("Pain, load, and steps on one chart. Drag the scrubber to read a day.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ExploreStylePicker(raw: $chartStyleRaw)
                            KneeExploreChart(
                                points: explorePoints,
                                height: 140,
                                // Viewport matches the picker through 90 days. Longer All windows scroll.
                                visibleDays: range.chartVisibleDays(windowDays: windowDays),
                                volumeTitle: primaryLoad.chartVolumeTitle,
                                emptyDescription: progressEmptyDescription,
                                style: ProgressChartStyle.resolved(chartStyleRaw)
                            )
                            .id(range.id + "-\(windowDays)")
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(AppTheme.cardHairline, lineWidth: 1)
                        )

                        heroRow

                        if let settings, settings.currentPhase == .aFlareDeLoad {
                            phaseACard(settings)
                        }

                        if let phaseBCleanCount {
                            phaseBCard(phaseBCleanCount)
                        }

                        OutcomeMixCard(mix: outcomeMix)
                        ConsistencyCard(summary: consistency)
                    }
                }
                .padding()
            }
            .appCanvas()
            .navigationTitle("Progress")
        }
    }

    /// Top work-set weight for the primary lift. Walk-only days and other exercises stay nil.
    private func workingLoad(_ session: TrainingSession) -> Double? {
        guard !primaryLoad.isWalk else { return nil }
        guard ProgressionEngine.matchesPrimaryLoad(snapshot(session), title: primaryLoad.title) else { return nil }
        return session.chartMaxLoad
    }

    /// A walk log has steps or time and no weight. The QL walk primary never carries a load.
    private func walkOnly(_ session: TrainingSession) -> Bool {
        if primaryLoad.isWalk { return true }
        let sets = session.resistanceSets()
        let hasWalk = sets.contains { ($0.steps ?? 0) > 0 || ($0.durationMinutes ?? 0) > 0 }
        let hasLoad = sets.contains { !$0.isWarmup && $0.loadLbs != nil }
        return hasWalk && !hasLoad
    }

    private func snapshot(_ session: TrainingSession) -> TrainingSessionSnapshot {
        TrainingSessionSnapshot(
            id: session.id,
            date: session.date,
            createdAt: session.createdAt,
            sessionType: session.sessionType,
            response24h: session.response24h,
            decision: session.decision,
            resolvedAt: session.resolvedAt,
            snoozedUntil: session.snoozedUntil,
            phase: session.phase,
            painDuring: session.painDuring,
            painAfter: session.painAfter,
            isDraft: session.isDraft,
            whatIDid: session.whatIDid,
            resistanceSets: session.resistanceSets()
        )
    }

    private var progressEmptyDescription: String {
        "Your first morning pain log or first \(primaryLoad.title.lowercased()) session starts the charts. Progress is the diary filling in — not a grade."
    }

    private var heroRow: some View {
        HStack(spacing: 12) {
            heroChip(title: "Mornings", value: "\(consistency.morningDays)/\(consistency.windowDays)")
            heroChip(title: "Train days", value: "\(consistency.sessionDays)")
            heroChip(title: "Clean streak", value: "\(outcomeMix.cleanStreak)")
        }
    }

    private var rangeEyebrow: String {
        switch range {
        case .days7: return "Last 7 days"
        case .days28: return "Last 28 days"
        case .days90: return "Last 90 days"
        case .all: return "All logged days"
        }
    }

    private func interpretationCard(_ readout: ProgressWindowReadout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rangeEyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.quiet)
            Text(readout.headline)
                .font(.title2.weight(.semibold))
            if let detail = readout.detail {
                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(interpretationFill(readout.tone))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.cardHairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("progress-readout")
        .accessibilityLabel(
            [readout.headline, readout.detail].compactMap { $0 }.joined(separator: " ")
        )
    }

    private func interpretationFill(_ tone: ProgressWindowTone) -> Color {
        switch tone {
        case .positive:
            return Color.green.opacity(0.12)
        case .caution:
            return Color.orange.opacity(0.12)
        case .partial, .insufficient, .steady:
            return Color(.secondarySystemBackground)
        }
    }

    private func heroChip(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    private func phaseACard(_ settings: AppSettings) -> some View {
        let status = PhaseAExitEvaluator.evaluate(
            checkIns: checkIns.map(\.snapshot),
            settings: settings.phaseSnapshot,
            today: Date()
        )
        return VStack(alignment: .leading, spacing: 6) {
            Text("Phase A exit")
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
        .accessibilityElement(children: .combine)
    }

    private func phaseBCard(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Phase B clean sessions")
                .font(.subheadline.weight(.semibold))
            Text("\(count) Better/Same since you entered Phase B")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    RehabProgressView()
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
