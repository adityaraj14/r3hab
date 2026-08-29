import SwiftUI
import Charts

/// One named series for multi-line pain charts.
struct ChartSeriesLine: Identifiable {
    var id: String { label }
    var label: String
    var points: [DayValue]
    var color: Color
}

enum PainChartColors {
    static let knee = Color.accentColor
    static let left = Color(red: 0.91, green: 0.73, blue: 0.23)
    static let right = Color.orange
    static let load = Color.orange
}

/// Explorable knee chart: tap a day for AM pain + L/R load (lbs).
struct KneeExploreChart: View {
    let points: [DayExplorePoint]
    var height: CGFloat = 168
    var visibleDays: Int = 7

    @State private var selectedDate: Date?

    private var selected: DayExplorePoint? {
        guard let selectedDate else { return nil }
        return points.min { a, b in
            abs(a.date.timeIntervalSince(selectedDate)) < abs(b.date.timeIntervalSince(selectedDate))
        }
    }

    private var hasData: Bool {
        points.contains(where: \.hasValues)
    }

    private var loadDomainMax: Double {
        let loads = points.flatMap { [$0.leftLoadLbs, $0.rightLoadLbs] }.compactMap { $0 }
        return max(loads.max() ?? 20, 20)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasData {
                painChart
                loadChart
                selectionCard
            } else {
                ContentUnavailableView(
                    "No knee data yet",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Log AM pain or a seated-extension session to explore the trend.")
                )
                .frame(height: 140)
            }
        }
    }

    private var painChart: some View {
        Chart {
            ForEach(points) { point in
                if let am = point.amPain {
                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("AM pain", am)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(PainChartColors.knee)
                    PointMark(
                        x: .value("Day", point.date),
                        y: .value("AM pain", am)
                    )
                    .foregroundStyle(PainChartColors.knee)
                    .symbolSize(30)
                }
            }
            if let selected {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(PainChartColors.left.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: TimeInterval(visibleDays * 24 * 60 * 60))
        .chartYScale(domain: 0...10)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 5, 10])
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, visibleDays / 3))) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: height)
        .accessibilityLabel("AM pain chart. Tap a point for date, load, and pain.")
    }

    private var loadChart: some View {
        Chart {
            ForEach(points) { point in
                leftMarks(for: point)
                rightMarks(for: point)
            }
            selectionRule
        }
        .chartXSelection(value: $selectedDate)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: TimeInterval(visibleDays * 24 * 60 * 60))
        .chartYScale(domain: 0...loadDomainMax)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, visibleDays / 3))) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: height)
        .accessibilityLabel("L and R load in lbs. Scroll to zoom the date window.")
    }

    @ChartContentBuilder
    private func leftMarks(for point: DayExplorePoint) -> some ChartContent {
        if let left = point.leftLoadLbs {
            LineMark(
                x: .value("Day", point.date),
                y: .value("Load", left),
                series: .value("Side", "L")
            )
            .interpolationMethod(.linear)
            .foregroundStyle(PainChartColors.left)
            PointMark(
                x: .value("Day", point.date),
                y: .value("Load", left),
                series: .value("Side", "L")
            )
            .foregroundStyle(PainChartColors.left)
            .symbolSize(28)
        }
    }

    @ChartContentBuilder
    private func rightMarks(for point: DayExplorePoint) -> some ChartContent {
        if let right = point.rightLoadLbs {
            LineMark(
                x: .value("Day", point.date),
                y: .value("Load", right),
                series: .value("Side", "R")
            )
            .interpolationMethod(.linear)
            .foregroundStyle(PainChartColors.right)
            PointMark(
                x: .value("Day", point.date),
                y: .value("Load", right),
                series: .value("Side", "R")
            )
            .foregroundStyle(PainChartColors.right)
            .symbolSize(28)
        }
    }

    @ChartContentBuilder
    private var selectionRule: some ChartContent {
        if let selected {
            RuleMark(x: .value("Selected", selected.date))
                .foregroundStyle(PainChartColors.left.opacity(0.55))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
    }

    @ViewBuilder
    private var selectionCard: some View {
        if let selected {
            VStack(alignment: .leading, spacing: 6) {
                Text(selected.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 16) {
                    labeledValue("AM pain", selected.amPain.map { String(Int($0)) } ?? "—")
                    labeledValue("L load", selected.leftLoadLbs.map(LoadCopy.labeled) ?? "—")
                    labeledValue("R load", selected.rightLoadLbs.map(LoadCopy.labeled) ?? "—")
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .accessibilityElement(children: .combine)
        } else {
            Text("Tap a point for date, L/R load, and AM pain. Scroll sideways to move the window.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func labeledValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
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
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 140)
            } else {
                ContentUnavailableView(
                    "No data yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Log daily check-ins to see trends.")
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
