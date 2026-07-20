import SwiftUI
import Charts

struct SparklineView: View {
    let points: [DayValue]
    var yDomain: ClosedRange<Double>? = 0...10
    var lineColor: Color = .accentColor
    var height: CGFloat = 40

    private var plotted: [DayValue] {
        points.filter { $0.value != nil }
    }

    var body: some View {
        Chart {
            ForEach(plotted) { p in
                if let v = p.value {
                    LineMark(
                        x: .value("Day", p.date),
                        y: .value("Value", v)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(lineColor)

                    AreaMark(
                        x: .value("Day", p.date),
                        y: .value("Value", v)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(lineColor.opacity(0.15))
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
    let points: [DayValue]
    var yDomain: ClosedRange<Double> = 0...10
    var unitHint: String = ""

    private var avg: Double? { ChartMetricBuilder.average(of: points) }
    private var hasData: Bool { points.contains { $0.value != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if let avg {
                    Text("avg \(avg.formatted(.number.precision(.fractionLength(1))))\(unitHint)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if hasData {
                Chart {
                    ForEach(points.filter { $0.value != nil }) { p in
                        if let v = p.value {
                            LineMark(
                                x: .value("Day", p.date),
                                y: .value("Value", v)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.accentColor)

                            PointMark(
                                x: .value("Day", p.date),
                                y: .value("Value", v)
                            )
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .chartYScale(domain: yDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, points.count / 4))) { value in
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
