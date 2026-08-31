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
    var loadTitle: String = "Seated extension load"

    @State private var selectedDate: Date?

    private var calendar: Calendar { .current }

    private var selected: DayExplorePoint? {
        let target = selectedDate ?? defaultSelectedDate
        guard let target else { return nil }
        return points.min { a, b in
            abs(a.date.timeIntervalSince(target)) < abs(b.date.timeIntervalSince(target))
        }
    }

    private var defaultSelectedDate: Date? {
        points.last(where: \.hasValues)?.date
    }

    private var hasData: Bool {
        points.contains(where: \.hasValues)
    }

    private var allowsScroll: Bool {
        points.count > visibleDays
    }

    private var xDomain: ClosedRange<Date> {
        guard let first = points.first?.date, let last = points.last?.date else {
            let now = Date()
            return now...now
        }
        let start = calendar.date(byAdding: .hour, value: -10, to: first) ?? first
        let end = calendar.date(byAdding: .hour, value: 22, to: last) ?? last
        return start...end
    }

    private var loadDomainMax: Double {
        let loads = points.flatMap { [$0.leftLoadLbs, $0.rightLoadLbs] }.compactMap { $0 }
        let maxLoad = loads.max() ?? 20
        return max(maxLoad * 1.1, 20)
    }

    private var sidesDiverge: Bool {
        points.contains { point in
            guard let left = point.leftLoadLbs, let right = point.rightLoadLbs else { return false }
            return left != right
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if hasData {
                chartBlock(
                    title: "Morning pain",
                    unit: "0–10",
                    accessibility: "Morning pain, 0 to 10. Tap a day for details."
                ) {
                    painChart
                }
                chartBlock(
                    title: loadTitle,
                    unit: "lbs",
                    accessibility: "\(loadTitle) in pounds. Tap a day for details."
                ) {
                    loadChart
                }
                loadLegend
                selectionCard
            } else {
                ContentUnavailableView(
                    "No knee data yet",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Log AM pain or a session to explore the trend.")
                )
                .frame(height: 140)
            }
        }
        .onAppear {
            if selectedDate == nil {
                selectedDate = defaultSelectedDate
            }
        }
    }

    private func chartBlock<Content: View>(
        title: String,
        unit: String,
        accessibility: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(unit)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            content()
                .accessibilityLabel(accessibility)
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
                    .symbolSize(40)
                }
            }
            selectionRule
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...10)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 5, 10]) {
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .sharedExploreAxes(visibleDays: visibleDays, allowsScroll: allowsScroll)
        .frame(height: height)
        .chartDayPicker(points: points, selectedDate: $selectedDate, enableScrub: !allowsScroll)
    }

    private var loadChart: some View {
        Chart {
            ForEach(points) { point in
                leftMarks(for: point)
                if sidesDiverge {
                    rightMarks(for: point)
                }
            }
            selectionRule
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: 0...loadDomainMax)
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .sharedExploreAxes(visibleDays: visibleDays, allowsScroll: allowsScroll)
        .frame(height: height)
        .chartDayPicker(points: points, selectedDate: $selectedDate, enableScrub: !allowsScroll)
    }

    @ChartContentBuilder
    private func leftMarks(for point: DayExplorePoint) -> some ChartContent {
        if let load = sidesDiverge ? point.leftLoadLbs : (point.leftLoadLbs ?? point.rightLoadLbs) {
            LineMark(
                x: .value("Day", point.date),
                y: .value("Load", load),
                series: .value("Side", sidesDiverge ? "L" : "Load")
            )
            .interpolationMethod(.linear)
            .foregroundStyle(sidesDiverge ? PainChartColors.left : PainChartColors.load)
            PointMark(
                x: .value("Day", point.date),
                y: .value("Load", load)
            )
            .foregroundStyle(sidesDiverge ? PainChartColors.left : PainChartColors.load)
            .symbolSize(40)
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
                y: .value("Load", right)
            )
            .foregroundStyle(PainChartColors.right)
            .symbolSize(40)
        }
    }

    @ChartContentBuilder
    private var selectionRule: some ChartContent {
        if let selected {
            RuleMark(x: .value("Selected", selected.date))
                .foregroundStyle(Color.primary.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
    }

    @ViewBuilder
    private var loadLegend: some View {
        if sidesDiverge {
            HStack(spacing: 14) {
                legendDot(PainChartColors.left, "Left load")
                legendDot(PainChartColors.right, "Right load")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
        }
    }

    @ViewBuilder
    private var selectionCard: some View {
        if let selected {
            VStack(alignment: .leading, spacing: 6) {
                Text(selected.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 16) {
                    labeledValue("Morning pain", selected.amPain.map { String(Int($0)) } ?? "—")
                    if sidesDiverge {
                        labeledValue("Left", selected.leftLoadLbs.map(LoadCopy.labeled) ?? "—")
                        labeledValue("Right", selected.rightLoadLbs.map(LoadCopy.labeled) ?? "—")
                    } else {
                        labeledValue(
                            "Load",
                            (selected.leftLoadLbs ?? selected.rightLoadLbs).map(LoadCopy.labeled) ?? "—"
                        )
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .accessibilityElement(children: .combine)
        }
        Text(allowsScroll
             ? "Tap a day for details. Scroll sideways to move the window."
             : "Tap a day for morning pain and load.")
            .font(.caption)
            .foregroundStyle(.secondary)
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

private extension View {
    func sharedExploreAxes(visibleDays: Int, allowsScroll: Bool) -> some View {
        self
            .chartPlotStyle { plot in
                plot.padding(.horizontal, 10)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, visibleDays / 3))) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .modifier(ExploreScrollModifier(visibleDays: visibleDays, enabled: allowsScroll))
    }

    func chartDayPicker(points: [DayExplorePoint], selectedDate: Binding<Date?>, enableScrub: Bool) -> some View {
        modifier(ChartDayPickerModifier(points: points, selectedDate: selectedDate, enableScrub: enableScrub))
    }
}

private struct ExploreScrollModifier: ViewModifier {
    var visibleDays: Int
    var enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: TimeInterval(visibleDays * 24 * 60 * 60) + 12 * 60 * 60)
        } else {
            content
        }
    }
}

/// Tap/scrub overlay so day selection works even when Charts' built-in selection does not.
private struct ChartDayPickerModifier: ViewModifier {
    let points: [DayExplorePoint]
    @Binding var selectedDate: Date?
    var enableScrub: Bool

    func body(content: Content) -> some View {
        content
            .chartOverlay { _ in
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            SpatialTapGesture()
                                .onEnded { event in
                                    select(atX: event.location.x, width: geo.size.width)
                                }
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: enableScrub ? 8 : 10_000)
                                .onChanged { value in
                                    select(atX: value.location.x, width: geo.size.width)
                                }
                        )
                }
            }
    }

    private func select(atX x: CGFloat, width: CGFloat) {
        guard width > 0, points.count > 1 else {
            selectedDate = points.first?.date
            return
        }
        let t = max(0, min(1, x / width))
        let index = Int((t * CGFloat(points.count - 1)).rounded())
        let clamped = max(0, min(points.count - 1, index))
        selectedDate = points[clamped].date
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
