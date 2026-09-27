import SwiftUI
import Charts

/// Colors for the Progress chart. Dark canvas, one gold accent.
enum ExplorePalette {
    static let pain = AppTheme.gold
    static let load = Color(red: 1.0, green: 0.55, blue: 0.25)
    static let steps = Color(red: 0.62, green: 0.86, blue: 1.0)
    static let track = Color.white.opacity(0.08)
}

enum ExplorePlotMetrics {
    static func plotWidth(width: CGFloat, leading: CGFloat, trailing: CGFloat) -> CGFloat {
        max(width - leading - trailing, 1)
    }

    static func x(
        for date: Date,
        in points: [DayExplorePoint],
        width: CGFloat,
        leading: CGFloat,
        trailing: CGFloat
    ) -> CGFloat {
        let plot = plotWidth(width: width, leading: leading, trailing: trailing)
        return leading + CGFloat(ChartDaySelection.plotX(for: date, in: points, width: Double(plot)))
    }

    static func point(
        at locationX: CGFloat,
        width: CGFloat,
        leading: CGFloat,
        trailing: CGFloat,
        points: [DayExplorePoint]
    ) -> DayExplorePoint? {
        let plot = plotWidth(width: width, leading: leading, trailing: trailing)
        return ChartDaySelection.point(
            atPlotX: Double(locationX - leading),
            width: Double(plot),
            points: points
        )
    }
}

/// Pain, load, and steps as three lanes on one date axis.
struct KneeExploreChart: View {
    let points: [DayExplorePoint]
    var height: CGFloat = 248
    var visibleDays: Int = 7
    var emptyDescription: String = "Log morning or evening pain, steps, or a session. The chart reads the days you actually logged."

    @State private var selectedDate: Date?
    @State private var plotInsets = PlotInsets(leading: ProgressLanesPlot.labelGutter, trailing: 8)

    private var selected: DayExplorePoint? {
        let target = selectedDate ?? defaultSelectedDate
        guard let target else { return nil }
        return ChartDaySelection.nearestPoint(to: target, in: points)
    }

    private var defaultSelectedDate: Date? {
        points.last(where: \.hasValues)?.date
    }

    private var hasData: Bool {
        points.contains(where: \.hasValues)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasData {
                ExploreLegend()
                ProgressLanesPlot(
                    points: points,
                    visibleDays: visibleDays,
                    selectedDate: $selectedDate
                )
                .frame(height: max(height, 220))
                .accessibilityLabel("Pain, load, and steps. Pain is a solid 0 to 10 line. Load is a bar per session. Steps are a dotted line.")
                .onPreferenceChange(PlotInsetsKey.self) { plotInsets = $0 }
                if let selected {
                    ExploreScrubber(
                        points: points,
                        selectedDate: $selectedDate,
                        leadingInset: plotInsets.leading,
                        trailingInset: plotInsets.trailing,
                        summary: daySummary(selected)
                    )
                    ExploreDayReadout(point: selected)
                }
                Text("Drag the scrubber. One line reads that day on every lane.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ContentUnavailableView(
                    "The trend starts with one honest number",
                    systemImage: "chart.xyaxis.line",
                    description: Text(emptyDescription)
                )
                .frame(height: 140)
            }
        }
        .accessibilityIdentifier("progress-explore-chart")
        .onAppear {
            if selectedDate == nil {
                selectedDate = defaultSelectedDate
            }
        }
        .onChange(of: points.map(\.dayKey)) { _, _ in
            guard let selectedDate else { return }
            if ChartDaySelection.nearestPoint(to: selectedDate, in: points) == nil {
                self.selectedDate = defaultSelectedDate
            }
        }
    }

    private func daySummary(_ point: DayExplorePoint) -> String {
        let date = point.date.formatted(date: .abbreviated, time: .omitted)
        if let line = LaneScrubReadout.line(point: point) {
            return "\(date). \(line)."
        }
        return "\(date). \(LaneScrubReadout.emptyDay)."
    }
}

private struct ExploreLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            item(ExplorePalette.pain, "Pain", accessibility: "Pain")
            item(ExplorePalette.load, "Load", accessibility: "Load in pounds")
            item(ExplorePalette.steps, "Steps", accessibility: "Steps")
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
    }

    private func item(_ color: Color, _ title: String, accessibility: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }
}

private struct ExploreScrubber: View {
    let points: [DayExplorePoint]
    @Binding var selectedDate: Date?
    var leadingInset: CGFloat
    var trailingInset: CGFloat
    var summary: String

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(ExplorePalette.track)
                    .frame(height: 4)
                    .padding(.leading, leadingInset)
                    .padding(.trailing, trailingInset)
                tickRow(width: width)
                Circle()
                    .fill(AppTheme.gold)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.35), lineWidth: 1))
                    .position(x: thumbX(width: width), y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        select(at: value.location.x, width: width)
                    }
            )
        }
        .frame(height: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("progress-day-scrubber")
        .accessibilityLabel("Day scrubber")
        .accessibilityValue(summary)
        .accessibilityHint("Swipe up or down to move one day.")
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? 1 : -1
            guard let current = selectedDate ?? points.last?.date,
                  let next = ChartDaySelection.neighbor(of: current, in: points, step: step) else { return }
            assign(next)
        }
    }

    private func tickRow(width: CGFloat) -> some View {
        Canvas { context, size in
            for point in points where point.hasValues {
                let x = ExplorePlotMetrics.x(
                    for: point.date,
                    in: points,
                    width: width,
                    leading: leadingInset,
                    trailing: trailingInset
                )
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: size.height / 2 - 5))
                tick.addLine(to: CGPoint(x: x, y: size.height / 2 + 5))
                context.stroke(tick, with: .color(Color.white.opacity(0.28)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }

    private func thumbX(width: CGFloat) -> CGFloat {
        guard let date = selectedDate ?? points.last?.date else { return leadingInset }
        return ExplorePlotMetrics.x(
            for: date,
            in: points,
            width: width,
            leading: leadingInset,
            trailing: trailingInset
        )
    }

    private func select(at locationX: CGFloat, width: CGFloat) {
        assign(
            ExplorePlotMetrics.point(
                at: locationX,
                width: width,
                leading: leadingInset,
                trailing: trailingInset,
                points: points
            )
        )
    }

    private func assign(_ point: DayExplorePoint?) {
        guard let point, selectedDate != point.date else { return }
        Haptics.light()
        selectedDate = point.date
    }
}

private struct ExploreDayReadout: View {
    let point: DayExplorePoint

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(point.date.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline.weight(.semibold))
            Text(LaneScrubReadout.line(point: point) ?? LaneScrubReadout.emptyDay)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            ExploreDayDetails(point: point)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("progress-lane-readout")
        .accessibilityLabel(scrubLabel)
    }

    private var scrubLabel: String {
        let date = point.date.formatted(date: .abbreviated, time: .omitted)
        if let line = LaneScrubReadout.line(point: point) {
            return "\(date). \(line)."
        }
        return "\(date). \(LaneScrubReadout.emptyDay)."
    }
}

private struct ExploreDayDetails: View {
    let point: DayExplorePoint

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if point.morningPain != nil || point.eveningPain != nil {
                Text("Morning \(painText(point.morningPain)) · Evening \(painText(point.eveningPain))")
            }
            if point.duringPain != nil || point.afterPain != nil {
                Text("During \(painText(point.duringPain)) · After \(painText(point.afterPain))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func painText(_ value: Double?) -> String {
        value.map(LaneScrubReadout.formatPain) ?? "—"
    }
}

// MARK: - Lanes

private struct ProgressLanesPlot: View {
    static let labelGutter: CGFloat = 44

    let points: [DayExplorePoint]
    var visibleDays: Int
    @Binding var selectedDate: Date?

    private var calendar: Calendar { .current }

    private var loadPeak: Double {
        ExploreSignalScale.peak(points.map(\.loadLbs))
    }

    private var stepsPeak: Double {
        ExploreSignalScale.peak(points.map(\.steps))
    }

    private var labeledDayKeys: Set<String> {
        let indexes = points.enumerated().compactMap { index, point -> Int? in
            guard point.loadLbs != nil, let label = point.repLabel, !label.isEmpty else { return nil }
            return index
        }
        let shown = RepLabelVisibility.shown(sessionDayIndexes: indexes, dayCount: points.count)
        return Set(shown.map { points[$0].dayKey })
    }

    private var barWidth: CGFloat {
        let days = CGFloat(max(min(points.count, max(visibleDays, 1)), 1))
        return min(16, max(2.5, 180 / days))
    }

    private var xDomain: ClosedRange<Date> {
        guard let first = points.first?.date, let last = points.last?.date else {
            let now = Date()
            return now...now
        }
        let start = calendar.date(byAdding: .hour, value: -10, to: first) ?? first
        let end = calendar.date(byAdding: .hour, value: 14, to: last) ?? last
        return start...end
    }

    private var xStride: Int {
        max(1, min(points.count, visibleDays) / 3)
    }

    private var allowsScroll: Bool {
        points.count > visibleDays
    }

    var body: some View {
        chart
            .modifier(ExploreScrollModifier(visibleDays: visibleDays, enabled: allowsScroll, scrollDate: $scrollDate))
            .modifier(ChartDayPickerModifier(points: points, selectedDate: $selectedDate, enableScrub: !allowsScroll))
            .onAppear {
                guard allowsScroll else { return }
                scrollDate = scrollAnchor(for: selectedDate ?? points.last?.date ?? Date())
            }
            .onChange(of: selectedDate) { _, newValue in
                guard allowsScroll, let newValue else { return }
                scrollDate = scrollAnchor(for: newValue)
            }
    }

    @State private var scrollDate = Date()

    private func scrollAnchor(for date: Date) -> Date {
        calendar.date(byAdding: .day, value: -(max(visibleDays, 1) / 2), to: date) ?? date
    }

    private var chart: some View {
        Chart {
            laneGuides
            painMarks
            loadMarks
            stepMarks
            if let selected = selectedDate.flatMap({ ChartDaySelection.nearestPoint(to: $0, in: points) }) {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(AppTheme.gold.opacity(0.95))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartYScale(domain: LaneScale.domain)
        .chartYAxis(.hidden)
        .chartXScale(domain: xDomain)
        .chartLegend(.hidden)
        .chartPlotStyle { plot in
            plot.padding(.leading, Self.labelGutter).padding(.trailing, 8)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xStride)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let plotFrame = proxy.plotFrame {
                    let plot = geo[plotFrame]
                    ZStack {
                        Color.clear.preference(
                            key: PlotInsetsKey.self,
                            value: PlotInsets(
                                leading: plot.minX,
                                trailing: max(0, geo.size.width - plot.maxX)
                            )
                        )
                        laneTitle("Pain", detail: "0–10", color: ExplorePalette.pain, at: 2.50, plot: plot)
                        laneTitle("Load", detail: "lb", color: ExplorePalette.load, at: 1.40, plot: plot)
                        laneTitle("Steps", detail: nil, color: ExplorePalette.steps, at: 0.43, plot: plot)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    @ChartContentBuilder
    private var laneGuides: some ChartContent {
        RuleMark(y: .value("Pain floor", LaneScale.pain.floor))
            .foregroundStyle(Color.white.opacity(0.10))
        RuleMark(y: .value("Load floor", LaneScale.load.floor))
            .foregroundStyle(Color.white.opacity(0.10))
        RuleMark(y: .value("Steps floor", LaneScale.steps.floor))
            .foregroundStyle(Color.white.opacity(0.10))
        RuleMark(y: .value("Upper split", 1.96))
            .foregroundStyle(Color.white.opacity(0.14))
        RuleMark(y: .value("Lower split", 0.96))
            .foregroundStyle(Color.white.opacity(0.14))
    }

    @ChartContentBuilder
    private var painMarks: some ChartContent {
        let segments = ExploreSeries.contiguousSegments(points, value: \.pain)
        ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
            ForEach(segment) { point in
                if let pain = point.pain {
                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("Pain", LaneScale.pain.y(pain / 10)),
                        series: .value("Pain", "pain-\(index)")
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(ExplorePalette.pain)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
            if segment.count == 1, let only = segment.first, let pain = only.pain {
                PointMark(
                    x: .value("Day", only.date),
                    y: .value("Pain", LaneScale.pain.y(pain / 10))
                )
                .foregroundStyle(ExplorePalette.pain)
                .symbolSize(28)
            }
        }
    }

    @ChartContentBuilder
    private var loadMarks: some ChartContent {
        ForEach(points) { point in
            if let load = point.loadLbs {
                BarMark(
                    x: .value("Day", point.date),
                    yStart: .value("Load base", LaneScale.load.floor),
                    yEnd: .value("Load", loadTop(load)),
                    width: .fixed(barWidth)
                )
                .foregroundStyle(ExplorePalette.load.opacity(0.92))
                .cornerRadius(2)
                .annotation(position: .top, spacing: 1) {
                    if let label = point.repLabel, labeledDayKeys.contains(point.dayKey) {
                        Text(label)
                            .font(repLabelFont)
                            .foregroundStyle(ExplorePalette.load)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    @ChartContentBuilder
    private var stepMarks: some ChartContent {
        let segments = ExploreSeries.contiguousSegments(points, value: \.steps)
        ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
            ForEach(segment) { point in
                if let steps = point.steps,
                   let unit = ExploreSignalScale.unit(steps, peak: stepsPeak) {
                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("Steps", LaneScale.steps.y(unit)),
                        series: .value("Steps", "steps-\(index)")
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(ExplorePalette.steps)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 3.5]))
                }
            }
            if segment.count == 1, let only = segment.first, let steps = only.steps,
               let unit = ExploreSignalScale.unit(steps, peak: stepsPeak) {
                PointMark(
                    x: .value("Day", only.date),
                    y: .value("Steps", LaneScale.steps.y(unit))
                )
                .foregroundStyle(ExplorePalette.steps)
                .symbolSize(24)
            }
        }
    }

    private var repLabelFont: Font {
        if points.count > 10 {
            return .system(size: 8, weight: .semibold)
        }
        return .caption2.weight(.bold)
    }

    private func loadTop(_ load: Double) -> Double {
        let unit = ExploreSignalScale.unit(load, peak: loadPeak) ?? 0
        return max(LaneScale.load.y(unit), LaneScale.load.floor + 0.035)
    }

    private func laneTitle(
        _ title: String,
        detail: String?,
        color: Color,
        at value: Double,
        plot: CGRect
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption2.weight(.semibold))
            if let detail {
                Text(detail)
                    .font(.system(size: 8, weight: .medium))
            }
        }
        .foregroundStyle(color)
        .position(x: plot.minX - Self.labelGutter / 2, y: plotY(value, plot: plot))
        .accessibilityHidden(true)
    }

    private func plotY(_ value: Double, plot: CGRect) -> CGFloat {
        let span = LaneScale.domain.upperBound - LaneScale.domain.lowerBound
        let t = (LaneScale.domain.upperBound - value) / span
        return plot.minY + CGFloat(t) * plot.height
    }
}

private struct PlotInsets: Equatable {
    var leading: CGFloat
    var trailing: CGFloat
}

private struct PlotInsetsKey: PreferenceKey {
    static var defaultValue = PlotInsets(leading: ProgressLanesPlot.labelGutter, trailing: 8)

    static func reduce(value: inout PlotInsets, nextValue: () -> PlotInsets) {
        value = nextValue()
    }
}

private struct LaneScale {
    var floor: Double
    var ceiling: Double

    func y(_ unit: Double) -> Double {
        let t = min(1, max(0, unit))
        return floor + t * (ceiling - floor)
    }

    static let steps = LaneScale(floor: 0.08, ceiling: 0.78)
    static let load = LaneScale(floor: 1.10, ceiling: 1.68)
    static let pain = LaneScale(floor: 2.12, ceiling: 2.90)
    static let domain = 0.0...3.0
}


private struct ExploreScrollModifier: ViewModifier {
    var visibleDays: Int
    var enabled: Bool
    @Binding var scrollDate: Date

    func body(content: Content) -> some View {
        if enabled {
            content
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: TimeInterval(visibleDays) * 24 * 60 * 60 + 12 * 60 * 60)
                .chartScrollPosition(x: $scrollDate)
        } else {
            content
        }
    }
}

/// Tap, and drag when the chart itself is not scrolling, so one day is chosen across every lane.
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
                                    guard enableScrub else { return }
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
        let day: DayExplorePoint?
        if let date = proxy.value(atX: plotX, as: Date.self) {
            day = ChartDaySelection.nearestPoint(to: date, in: points)
        } else {
            day = ChartDaySelection.point(atPlotX: Double(plotX), width: Double(geo.size.width), points: points)
        }
        guard let day, selectedDate != day.date else { return }
        Haptics.light()
        selectedDate = day.date
    }
}

#Preview("7 days") {
    LanePreview(days: ExplorePreviewData.week(ending: Date()), visibleDays: 7)
        .preferredColorScheme(.dark)
}

#Preview("28 days") {
    LanePreview(days: ExplorePreviewData.month(ending: Date()), visibleDays: 28)
        .preferredColorScheme(.dark)
}

private struct LanePreview: View {
    var days: [DayExplorePoint]
    var visibleDays: Int

    var body: some View {
        ScrollView {
            KneeExploreChart(points: days, visibleDays: visibleDays)
                .padding()
        }
        .background(Color.black)
    }
}

private enum ExplorePreviewData {
    static func month(ending today: Date) -> [DayExplorePoint] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        return (0..<28).map { index in
            let date = calendar.date(byAdding: .day, value: index - 27, to: start)!
            let trained = index % 3 == 0
            let pain: Double? = index % 5 == 2 ? nil : Double(max(1, 4 - index / 9))
            let steps: Double? = index % 4 == 1 ? nil : Double(3800 + index * 90)
            let load: Double? = trained ? Double(30 + index) : nil
            let label: String? = trained ? (index % 6 == 0 ? "8/8/6" : "3×8") : nil
            return DayExplorePoint(
                dayKey: CalendarDay.dayKey(date),
                date: date,
                pain: pain,
                volume: load.map { $0 * 24 },
                loadLbs: load,
                repLabel: label,
                steps: steps
            )
        }
    }

    static func week(ending today: Date) -> [DayExplorePoint] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        let pains: [Double?] = [3, 2, nil, 4, 3.5, 2, 1]
        let loads: [Double?] = [nil, 35, nil, 40, nil, 45, 45]
        let labels: [String?] = [nil, "3×8", nil, "8/8/6", nil, "3×10", "3×8"]
        let steps: [Double?] = [4200, 6100, 0, nil, 7300, 5400, 8000]
        return pains.indices.map { index in
            let date = calendar.date(byAdding: .day, value: index - 6, to: start)!
            return DayExplorePoint(
                dayKey: CalendarDay.dayKey(date),
                date: date,
                pain: pains[index],
                volume: loads[index].map { $0 * 24 },
                loadLbs: loads[index],
                repLabel: labels[index],
                steps: steps[index]
            )
        }
    }
}
