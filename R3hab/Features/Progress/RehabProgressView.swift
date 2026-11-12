import SwiftUI
import SwiftData

/// Progress tab — pain vs volume, 24h outcomes, consistency.
struct RehabProgressView: View {
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]
    @Query private var settingsList: [AppSettings]

    @State private var range: ProgressDayRange = .days7

    private var settings: AppSettings? { settingsList.first }
    private var calendar: Calendar { .current }

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
        sessions.filter(\.isComplete)
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
            sessions: finalizedSessions.map { loadSnapshot($0) },
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
                            "No pain records or sessions yet",
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
                            KneeExploreChart(
                                points: explorePoints,
                                // Viewport matches the picker through 90 days. Longer All windows scroll.
                                visibleDays: range.chartVisibleDays(windowDays: windowDays),
                                emptyDescription: progressEmptyDescription
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

                        if InjuryCatalog.isPatellar(settings?.selectedInjuryID ?? InjuryCatalog.patellarTendinopathy.id) {
                            declineTrendCard
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

    /// Volume always feeds the interpretation readout. The load chart takes any
    /// session with a positive work-set weight. Walks have steps or time and no
    /// weight, so they leave an empty slot. Side bends and hip thrusts use the
    /// same line and sets × reps label as a knee lift. Warm-ups are excluded.
    private func loadSnapshot(_ session: TrainingSession) -> SessionLoadSnapshot {
        let sets = session.resistanceSets()
        return SessionLoadSnapshot(
            date: session.date,
            createdAt: session.createdAt,
            volume: session.chartVolume,
            loadLbs: WorkingSetReps.topLoad(sets: sets),
            repLabel: WorkingSetReps.label(sets: sets)
        )
    }

    private var progressEmptyDescription: String {
        "Record the morning pain or one \(primaryLoad.title.lowercased()) session. The chart starts with that record."
    }

    private var heroRow: some View {
        HStack(spacing: 12) {
            heroChip(title: "Mornings", value: "\(consistency.morningDays)/\(consistency.windowDays)")
            heroChip(title: "Session days", value: "\(consistency.sessionDays)")
            heroChip(title: "Clean sessions", value: "\(outcomeMix.cleanStreak)")
        }
    }

    private var rangeEyebrow: String {
        switch range {
        case .days7: return "Last 7 days"
        case .days28: return "Last 28 days"
        case .days90: return "Last 90 days"
        case .all: return "All recorded days"
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

    private var declineTrendCard: some View {
        let start = settings?.programStartDate ?? Date()
        let programStart = TwelveWeekPlan.isUnsetStart(start) ? Date() : start
        let trend = TwelveWeekPlan.declineTrend(
            start: programStart,
            checkIns: checkIns.map(\.snapshot),
            asOf: Date(),
            calendar: calendar,
            sessions: sessions.map(\.snapshot),
            overrides: settings?.planOverrides ?? []
        )
        return VStack(alignment: .leading, spacing: 6) {
            Text("Decline squat")
                .font(.subheadline.weight(.semibold))
            Text(trend.headline)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if !trend.points.isEmpty {
                Text(trend.points.map { "W\($0.week) \($0.score)" }.joined(separator: " · "))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    RehabProgressView()
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
