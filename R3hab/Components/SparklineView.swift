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

/// Explorable knee chart: tap a day for averaged AM/PM pain + L/R load (lbs).
struct KneeExploreChart: View {
    let points: [DayExplorePoint]
    var height: CGFloat = 168
    var visibleDays: Int = 7
    var loadTitle: String = "Seated extension load"
    var emptyDescription: String = "Log morning or evening pain or a seated-extension session. Load vs pain is the insight."

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
                    title: "Pain",
                    subtitle: "Average of morning and evening check-ins",
                    unit: "0–10",
                    accessibility: "Pain, 0 to 10, average of morning and evening check-ins. Tap a day for details."
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
                    "The trend starts with one honest number",
                    systemImage: "chart.xyaxis.line",
                    description: Text(emptyDescription)
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
        subtitle: String? = nil,
        unit: String,
        accessibility: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
                if let pain = point.pain {
                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("Pain", pain)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(PainChartColors.knee)
                    PointMark(
                        x: .value("Day", point.date),
                        y: .value("Pain", pain)
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
                y: .value(sidesDiverge ? "Left load" : "Load", load)
            )
            .interpolationMethod(.linear)
            .foregroundStyle(sidesDiverge ? PainChartColors.left : PainChartColors.load)
            PointMark(
                x: .value("Day", point.date),
                y: .value(sidesDiverge ? "Left load" : "Load", load)
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
                y: .value("Right load", right)
            )
            .interpolationMethod(.linear)
            .foregroundStyle(PainChartColors.right)
            PointMark(
                x: .value("Day", point.date),
                y: .value("Right load", right)
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
                    labeledValue("Pain", Self.formatPain(selected.pain))
                    labeledValue("During", selected.duringPain.map { String(Int($0)) } ?? "—")
                    labeledValue("After", selected.afterPain.map { String(Int($0)) } ?? "—")
                }
                if selected.morningPain != nil || selected.eveningPain != nil {
                    Text("Morning \(Self.formatPain(selected.morningPain)) · Evening \(Self.formatPain(selected.eveningPain))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 16) {
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
             : "Tap a day for pain and load.")
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

    /// Whole numbers stay integer; half-scores show one decimal (e.g. 3.5).
    private static func formatPain(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value.rounded() == value {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
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
/// Maps through the chart proxy's date scale so 28-day (and scrolled) windows hit the
/// visible day, not an index stretched across the full series.
private struct ChartDayPickerModifier: ViewModifier {
    let points: [DayExplorePoint]
    @Binding var selectedDate: Date?
    var enableScrub: Bool

    func body(content: Content) -> some View {
        content
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Color.clear
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            SpatialTapGesture()
                                .onEnded { event in
                                    select(at: event.location, proxy: proxy, geo: geo)
                                }
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: enableScrub ? 8 : 10_000)
                                .onChanged { value in
                                    select(at: value.location, proxy: proxy, geo: geo)
                                }
                        )
                }
            }
    }

    private func select(at location: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        let plotX: CGFloat
        if let plotFrame = proxy.plotFrame {
            plotX = location.x - geo[plotFrame].origin.x
        } else {
            plotX = location.x
        }
        if let date = proxy.value(atX: plotX, as: Date.self) {
            selectedDate = ChartDaySelection.nearestPoint(to: date, in: points)?.date
            return
        }
        selectedDate = ChartDaySelection.point(
            atPlotX: Double(plotX),
            width: Double(geo.size.width),
            points: points
        )?.date
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

struct OutcomeMixCard: View {
    let mix: OutcomeMix

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("24h outcomes")
                .font(.headline)
            if mix.resolved == 0 && mix.pending == 0 {
                Text("Resolve a session tomorrow morning. Better / Same is what counts — not zero pain during the set.")
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
                        mixStat("Open", mix.pending, .orange)
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
            "24 hour outcomes. Clean streak \(mix.cleanStreak). Better \(mix.better), same \(mix.same), worse \(mix.worse)."
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
            Text("Showing up")
                .font(.headline)
            Text(encouragement)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            meter(title: "Check-ins", value: summary.checkInDays, total: summary.windowDays)
            meter(title: "Mornings", value: summary.morningDays, total: summary.windowDays)
            meter(title: "Train days", value: summary.sessionDays, total: summary.windowDays)
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
            "Consistency. \(summary.checkInDays) of \(summary.windowDays) check-ins. \(summary.sessionDays) train days. \(summary.sessionCount) sessions."
        )
    }

    private var encouragement: String {
        if summary.checkInDays == 0 {
            return "One morning score is a start. The diary is the rehab."
        }
        if summary.checkInDays >= summary.windowDays {
            return "Every day in this window has a mark. That’s the habit."
        }
        return "\(summary.checkInDays) of \(summary.windowDays) days logged. Keep it going."
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

