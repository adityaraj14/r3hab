import SwiftUI
import SwiftData

/// Progress tab — pain vs load, 24h outcomes, consistency, load trail.
struct RehabProgressView: View {
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]
    @Query private var settingsList: [AppSettings]

    @State private var range: DayRange = .days7

    enum DayRange: Int, CaseIterable, Identifiable {
        case days7 = 7
        case days28 = 28
        var id: Int { rawValue }
        var title: String { rawValue == 7 ? "7 days" : "28 days" }
    }

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

    private var sessionPains: [SessionPainSnapshot] {
        sessions.map {
            SessionPainSnapshot(date: $0.date, painDuring: $0.painDuring, painAfter: $0.painAfter)
        }
    }

    private var sessionOutcomes: [SessionOutcomeSnapshot] {
        sessions.map {
            SessionOutcomeSnapshot(date: $0.date, createdAt: $0.createdAt, response24h: $0.response24h)
        }
    }

    private var explorePoints: [DayExplorePoint] {
        ChartMetricBuilder.explorePoints(
            checkIns: metrics,
            sideLoads: sessions.map {
                SessionSideLoadSnapshot(
                    date: $0.date,
                    leftMaxLbs: $0.chartMaxLoadLeft,
                    rightMaxLbs: $0.chartMaxLoadRight,
                    unspecifiedMaxLbs: $0.chartMaxLoad
                )
            },
            dayCount: range.rawValue,
            sessionPains: sessionPains
        )
    }

    private var outcomeMix: OutcomeMix {
        ChartMetricBuilder.outcomeMix(
            sessions: sessionOutcomes,
            dayCount: range.rawValue
        )
    }

    private var consistency: ConsistencySummary {
        ChartMetricBuilder.consistency(
            checkIns: metrics,
            sessions: sessionOutcomes,
            dayCount: range.rawValue
        )
    }

    /// Phase B stretch: clean sessions since phase change while in B (REQ-FUNC-017).
    private var phaseBCleanCount: Int? {
        guard let settings, settings.currentPhase == .bIsometrics else { return nil }
        return sessions.filter {
            $0.date >= settings.phaseChangedAt
                && $0.phase == .bIsometrics
                && ($0.response24h == .better || $0.response24h == .same)
        }.count
    }

    private var hasAnyData: Bool {
        !checkIns.isEmpty || !sessions.isEmpty
    }

    private var primaryLoad: PrimaryLoadOption {
        settings?.primaryLoad ?? PrimaryLoadCatalog.defaultSelectable(for: settings?.protocolTrack ?? .knee)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !hasAnyData {
                        ContentUnavailableView(
                            "Your first votes are still coming",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text(progressEmptyDescription)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        Picker("Range", selection: $range) {
                            ForEach(DayRange.allCases) { r in
                                Text(r.title).tag(r)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Chart range")

                        heroRow

                        if let settings, settings.currentPhase == .aFlareDeLoad {
                            phaseACard(settings)
                        }

                        if let phaseBCleanCount {
                            phaseBCard(phaseBCleanCount)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Load vs next morning")
                                .font(.headline)
                            Text("Mild pain during load is OK if mornings stay calm. Tap a day.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            KneeExploreChart(
                                points: explorePoints,
                                height: 140,
                                // Must match the picker. Capping at 7 kept 28-day on a 7-day domain.
                                visibleDays: range.rawValue,
                                loadTitle: primaryLoad.chartLoadTitle,
                                showsLoad: primaryLoad.plotsLoad,
                                emptyDescription: progressEmptyDescription
                            )
                            .id(range.rawValue)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )

                        OutcomeMixCard(mix: outcomeMix)
                        ConsistencyCard(summary: consistency)
                    }
                }
                .padding()
            }
            .navigationTitle("Progress")
        }
    }

    private var progressEmptyDescription: String {
        if primaryLoad.track == .ql {
            if primaryLoad.plotsLoad {
                return "Log morning or evening pain or a \(primaryLoad.title.lowercased()) session. Progress is the diary filling in — not a grade."
            }
            return "Log morning or evening pain or a walk. Walking stays time-based — no fake lbs."
        }
        return "Log morning or evening pain or a seated-extension session. Progress is the diary filling in — not a grade."
    }

    private var heroRow: some View {
        HStack(spacing: 12) {
            heroChip(title: "Mornings", value: "\(consistency.morningDays)/\(consistency.windowDays)")
            heroChip(title: "Train days", value: "\(consistency.sessionDays)")
            heroChip(title: "Clean streak", value: "\(outcomeMix.cleanStreak)")
        }
    }

    private func heroChip(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(Color.accentColor)
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
