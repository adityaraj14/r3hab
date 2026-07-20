import SwiftUI
import SwiftData

/// Trends tab — 7/28 day charts (PR-10).
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

    private var amSeries: [DayValue] {
        ChartMetricBuilder.series(rows: metrics, metric: .restingAM, dayCount: range.rawValue)
    }

    private var pmSeries: [DayValue] {
        ChartMetricBuilder.series(rows: metrics, metric: .dailyPM, dayCount: range.rawValue)
    }

    private var stepsSeries: [DayValue] {
        ChartMetricBuilder.series(rows: metrics, metric: .steps, dayCount: range.rawValue)
    }

    private var cleanSessions: Int {
        sessions.filter {
            $0.response24h == .better || $0.response24h == .same
        }.count
    }

    private var pendingCount: Int {
        sessions.filter { $0.response24h == .pending }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Range", selection: $range) {
                        ForEach(DayRange.allCases) { r in
                            Text(r.title).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)

                    statsRow

                    if let settings = settingsList.first, settings.currentPhase == .aFlareDeLoad {
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
                    }

                    MetricChartCard(title: "Resting pain AM", points: amSeries, yDomain: 0...10)
                    MetricChartCard(title: "Daily pain PM", points: pmSeries, yDomain: 0...10)
                    MetricChartCard(title: "Steps", points: stepsSeries, yDomain: 0...(maxStepsDomain), unitHint: "")
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
    }
}

#Preview {
    RehabProgressView()
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
