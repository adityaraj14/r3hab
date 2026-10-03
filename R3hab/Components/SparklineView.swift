import SwiftUI
import Charts

/// One named series for multi-line pain charts.
struct ChartSeriesLine: Identifiable {
    var id: String { label }
    var label: String
    var points: [DayValue]
    var color: Color
}


private struct MetricChartXScaleModifier: ViewModifier {
    var domain: ClosedRange<Date>?

    func body(content: Content) -> some View {
        if let domain {
            content.chartXScale(domain: domain)
        } else {
            content
        }
    }
}


struct MetricChartCard: View {
    let title: String
    let series: [ChartSeriesLine]
    var yDomain: ClosedRange<Double> = 0...10
    var unitHint: String = ""

    init(
        title: String,
        points: [DayValue],
        yDomain: ClosedRange<Double> = 0...10,
        unitHint: String = "",
        lineColor: Color = .accentColor
    ) {
        self.title = title
        self.series = [ChartSeriesLine(label: title, points: points, color: lineColor)]
        self.yDomain = yDomain
        self.unitHint = unitHint
    }

    private var hasData: Bool {
        series.contains { line in line.points.contains { $0.value != nil } }
    }

    private var xDomain: ClosedRange<Date>? {
        let dates = series.flatMap { line in line.points.map(\.date) }
        guard let first = dates.min(), let last = dates.max() else { return nil }
        return first...last
    }

    private var xStrideDays: Int {
        guard let xDomain else { return 4 }
        let days = Calendar.current.dateComponents([.day], from: xDomain.lowerBound, to: xDomain.upperBound).day ?? 7
        return max(1, days / 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            if hasData {
                Chart {
                    ForEach(series) { line in
                        ForEach(line.points.filter { $0.value != nil }) { point in
                            if let value = point.value {
                                LineMark(
                                    x: .value("Day", point.date),
                                    y: .value(line.label, value)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(line.color)
                                PointMark(
                                    x: .value("Day", point.date),
                                    y: .value(line.label, value)
                                )
                                .foregroundStyle(line.color)
                            }
                        }
                    }
                }
                .chartYScale(domain: yDomain)
                .modifier(MetricChartXScaleModifier(domain: xDomain))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: xStrideDays)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 140)
            } else {
                ContentUnavailableView(
                    "No data yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Record check-ins to see the trend.")
                )
                .frame(height: 120)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct OutcomeMixCard: View {
    let mix: OutcomeMix

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("24-hour responses")
                .font(.headline)
            if mix.resolved == 0 && mix.pending == 0 {
                Text("Record the 24-hour response the next morning. A clean session is Better or Same. Zero pain during the set is not required.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(mix.cleanStreak)")
                        .font(.largeTitle.monospacedDigit().weight(.bold))
                        .foregroundStyle(.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mix.cleanStreak == 1 ? "clean session" : "clean sessions")
                            .font(.subheadline.weight(.semibold))
                        Text("Better or Same in a row")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                mixBar
                HStack {
                    mixStat("Better", mix.better, .green)
                    mixStat("Same", mix.same, .secondary)
                    mixStat("Worse", mix.worse, .orange)
                    if mix.pending > 0 {
                        mixStat("Pending", mix.pending, .orange)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "24-hour responses. Clean sessions \(mix.cleanStreak). Better \(mix.better), same \(mix.same), worse \(mix.worse)."
        )
    }

    @ViewBuilder
    private var mixBar: some View {
        let total = max(mix.resolved + mix.pending, 1)
        GeometryReader { geo in
            HStack(spacing: 3) {
                if mix.better > 0 {
                    Capsule().fill(Color.green).frame(width: geo.size.width * CGFloat(mix.better) / CGFloat(total))
                }
                if mix.same > 0 {
                    Capsule().fill(Color.secondary.opacity(0.55)).frame(width: geo.size.width * CGFloat(mix.same) / CGFloat(total))
                }
                if mix.worse > 0 {
                    Capsule().fill(Color.orange).frame(width: geo.size.width * CGFloat(mix.worse) / CGFloat(total))
                }
                if mix.pending > 0 {
                    Capsule().fill(Color.white.opacity(0.25)).frame(width: geo.size.width * CGFloat(mix.pending) / CGFloat(total))
                }
            }
        }
        .frame(height: 10)
    }

    private func mixStat(_ title: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ConsistencyCard: View {
    let summary: ConsistencySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Records")
                .font(.headline)
            Text(encouragement)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            meter(title: "Check-ins", value: summary.checkInDays, total: summary.windowDays)
            meter(title: "Mornings", value: summary.morningDays, total: summary.windowDays)
            meter(title: "Session days", value: summary.sessionDays, total: summary.windowDays)
            Text("\(summary.sessionCount) session\(summary.sessionCount == 1 ? "" : "s") in this window")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Records. \(summary.checkInDays) of \(summary.windowDays) check-ins. \(summary.sessionDays) session days. \(summary.sessionCount) sessions."
        )
    }

    private var encouragement: String {
        if summary.checkInDays == 0 {
            return "Record one morning pain value. That record starts the chart."
        }
        if summary.checkInDays >= summary.windowDays {
            return "Every day in this window has a record."
        }
        return "\(summary.checkInDays) of \(summary.windowDays) days have a record."
    }

    private func meter(title: String, value: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(value)/\(total)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: geo.size.width * CGFloat(total == 0 ? 0 : Double(value) / Double(total)))
                }
            }
            .frame(height: 8)
        }
    }
}

