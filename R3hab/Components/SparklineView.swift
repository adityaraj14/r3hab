import SwiftUI
import Charts

/// One named series for multi-line pain charts.
struct ChartSeriesLine: Identifiable {
    var id: String { label }
    var label: String
    var points: [DayValue]
    var color: Color
}

struct SparklineView: View {
    let series: [ChartSeriesLine]
    var yDomain: ClosedRange<Double>? = 0...10
    var height: CGFloat = 40

    init(points: [DayValue], yDomain: ClosedRange<Double>? = 0...10, lineColor: Color = .accentColor, height: CGFloat = 40) {
        self.series = [ChartSeriesLine(label: "Value", points: points, color: lineColor)]
        self.yDomain = yDomain
        self.height = height
    }

    init(series: [ChartSeriesLine], yDomain: ClosedRange<Double>? = 0...10, height: CGFloat = 40) {
        self.series = series
        self.yDomain = yDomain
        self.height = height
    }

    var body: some View {
        Chart {
            ForEach(series) { line in
                ForEach(line.points.filter { $0.value != nil }) { p in
                    if let v = p.value {
                        LineMark(
                            x: .value("Day", p.date),
                            y: .value(line.label, v)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(line.color)

                        if series.count == 1 {
                            AreaMark(
                                x: .value("Day", p.date),
                                y: .value(line.label, v)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(line.color.opacity(0.15))
                        }
                    }
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: yDomain ?? 0...10)
        .frame(height: height)
        .accessibilityLabel("Trend chart")
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

    init(
        title: String,
        series: [ChartSeriesLine],
        yDomain: ClosedRange<Double> = 0...10,
        unitHint: String = ""
    ) {
        self.title = title
        self.series = series
        self.yDomain = yDomain
        self.unitHint = unitHint
    }

    private var hasData: Bool {
        series.contains { line in line.points.contains { $0.value != nil } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if series.count == 1, let avg = ChartMetricBuilder.average(of: series[0].points) {
                    Text("avg \(avg.formatted(.number.precision(.fractionLength(1))))\(unitHint)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if series.count > 1 {
                HStack(spacing: 12) {
                    ForEach(series) { line in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(line.color)
                                .frame(width: 8, height: 8)
                            Text(line.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let avg = ChartMetricBuilder.average(of: line.points) {
                                Text(avg.formatted(.number.precision(.fractionLength(1))))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            if hasData {
                Chart {
                    ForEach(series) { line in
                        ForEach(line.points.filter { $0.value != nil }) { p in
                            if let v = p.value {
                                LineMark(
                                    x: .value("Day", p.date),
                                    y: .value(line.label, v)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(by: .value("Series", line.label))

                                PointMark(
                                    x: .value("Day", p.date),
                                    y: .value(line.label, v)
                                )
                                .foregroundStyle(by: .value("Series", line.label))
                            }
                        }
                    }
                }
                .chartForegroundStyleScale(domain: series.map(\.label), range: series.map(\.color))
                .chartLegend(.hidden)
                .chartYScale(domain: yDomain)
                .chartXAxis {
                    let dayCount = series.first?.points.count ?? 7
                    AxisMarks(values: .stride(by: .day, count: max(1, dayCount / 4))) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 160)
            } else {
                ContentUnavailableView(
                    "No data yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Log daily check-ins to see trends.")
                )
                .frame(height: 140)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

enum PainChartColors {
    static let knee = Color.accentColor
    static let lowerBack = Color.teal
}
