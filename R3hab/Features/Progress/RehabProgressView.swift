import SwiftUI
import SwiftData

/// Trends tab — 7/28 day charts (PR-10/14).
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
                lowerBackPainAM: $0.lowerBackPainAM,
                lowerBackPainPM: $0.lowerBackPainPM,
                steps: $0.steps
            )
        }
    }

    private var loadPoints: [DayValue] {
        ChartMetricBuilder.loadSeries(
            sessions: sessions.map { SessionLoadSnapshot(date: $0.date, loadLbs: $0.loadLbs) },
            dayCount: range.rawValue
        )
    }

    private var kneeAM: [DayValue] {
        ChartMetricBuilder.series(rows: metrics, metric: .restingAM, dayCount: range.rawValue)
    }

    private var kneePM: [DayValue] {
        ChartMetricBuilder.series(rows: metrics, metric: .dailyPM, dayCount: range.rawValue)
    }

    private var backAM: [DayValue] {
        ChartMetricBuilder.series(rows: metrics, metric: .lowerBackAM, dayCount: range.rawValue)
    }

    private var backPM: [DayValue] {
        ChartMetricBuilder.series(rows: metrics, metric: .lowerBackPM, dayCount: range.rawValue)
    }

    private var stepsSeries: [DayValue] {
        ChartMetricBuilder.series(rows: metrics, metric: .steps, dayCount: range.rawValue)
    }

    private var cleanSessions: Int {
        sessions.filter {
            $0.response24h == .better || $0.response24h == .same
        }.count
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

    private var pendingCount: Int {
        sessions.filter { $0.response24h == .pending }.count
    }

    private var hasAnyData: Bool {
        !checkIns.isEmpty || !sessions.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !hasAnyData {
                        ContentUnavailableView(
                            "No trends yet",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Log this morning’s pain or a training session — charts fill in as you go.")
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

                        statsRow

                        if let settings, settings.currentPhase == .aFlareDeLoad {
                            let status = PhaseAExitEvaluator.evaluate(
                                checkIns: checkIns.map(\.snapshot),
                                settings: settings.phaseSnapshot,
                                today: Date()
                            )
                            VStack(alignment: .leading, spacing: 6) {
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

                        if let phaseBCleanCount {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Phase B clean sessions")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(phaseBCleanCount) Better/Same since you entered Phase B")
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

                        Text("Knee")
                            .font(.title3.weight(.semibold))
                            .padding(.top, 4)

                        MetricChartCard(
                            title: "Knee resting pain AM",
                            points: kneeAM,
                            yDomain: 0...10,
                            lineColor: PainChartColors.knee,
                            loadPoints: loadPoints
                        )
                        MetricChartCard(
                            title: "Knee daily pain PM",
                            points: kneePM,
                            yDomain: 0...10,
                            lineColor: PainChartColors.knee,
                            loadPoints: loadPoints
                        )

                        Text("Lower back")
                            .font(.title3.weight(.semibold))
                            .padding(.top, 4)

                        MetricChartCard(
                            title: "Back resting pain AM",
                            points: backAM,
                            yDomain: 0...10,
                            lineColor: PainChartColors.lowerBack
                        )
                        MetricChartCard(
                            title: "Back daily pain PM",
                            points: backPM,
                            yDomain: 0...10,
                            lineColor: PainChartColors.lowerBack
                        )

                        MetricChartCard(title: "Steps", points: stepsSeries, yDomain: 0...(maxStepsDomain), unitHint: "")
                    }
                }
                .padding()
            }
            .navigationTitle("Progress")
        }
    }

    private var maxStepsDomain: Double {
        let maxVal = stepsSeries.compactMap(\.value).max() ?? 10000
        return max(10000, maxVal * 1.1)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statChip(title: "Check-ins", value: "\(checkIns.count)")
            statChip(title: "Sessions", value: "\(sessions.count)")
            statChip(title: "Clean 24h", value: "\(cleanSessions)")
            if pendingCount > 0 {
                statChip(title: "Pending", value: "\(pendingCount)")
            }
        }
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    RehabProgressView()
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
