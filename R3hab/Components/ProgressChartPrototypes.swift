import SwiftUI
import Charts
#if canImport(UIKit)
import UIKit
#endif

/// Colors for the Progress charts. Dark canvas, one gold accent.
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

/// Pain, load, and steps as three charts on one date timeline.
struct KneeExploreChart: View {
    let points: [DayExplorePoint]
    var visibleDays: Int = 7
    var emptyDescription: String = "Log morning or evening pain, steps, or a session. The chart reads the days you actually logged."

    @State private var selectedDate: Date?
    @State private var scrollDate = Date()
    @State private var plotInsets = PlotInsets(
        leading: CGFloat(ExploreAxisLayout.yAxisWidth),
        trailing: CGFloat(ExploreAxisLayout.plotTrailingPadding)
    )

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

    private var allowsScroll: Bool {
        points.count > visibleDays
    }

    private var domain: ClosedRange<Date> {
        ExploreAxisLayout.xDomain(
            points: points,
            plotWidth: ExploreAxisLayout.proMaxPlotWidth,
            visibleDayCount: visibleDays
        )
    }

    private var axisDates: [Date] {
        ExploreAxisLayout.axisDates(
            points: points,
            plotWidth: ExploreAxisLayout.proMaxPlotWidth,
            visibleDayCount: visibleDays
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasData {
                ProgressMetricChart(
                    metric: .pain,
                    points: points,
                    visibleDays: visibleDays,
                    allowsScroll: allowsScroll,
                    domain: domain,
                    axisDates: axisDates,
                    selectedDate: $selectedDate,
                    scrollDate: $scrollDate
                )
                ProgressMetricChart(
                    metric: .load,
                    points: points,
                    visibleDays: visibleDays,
                    allowsScroll: allowsScroll,
                    domain: domain,
                    axisDates: axisDates,
                    selectedDate: $selectedDate,
                    scrollDate: $scrollDate
                )
                ProgressMetricChart(
                    metric: .steps,
                    points: points,
                    visibleDays: visibleDays,
                    allowsScroll: allowsScroll,
                    domain: domain,
                    axisDates: axisDates,
                    selectedDate: $selectedDate,
                    scrollDate: $scrollDate
                )
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
            } else {
                ContentUnavailableView(
                    "The trend starts with one honest number",
                    systemImage: "chart.xyaxis.line",
                    description: Text(emptyDescription)
                )
                .frame(height: 140)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ProgressChartAccessibility.chart)
        .onAppear {
            if selectedDate == nil {
                selectedDate = defaultSelectedDate
            }
            guard allowsScroll else { return }
            scrollDate = scrollAnchor(for: selectedDate ?? points.last?.date ?? Date())
        }
        .onChange(of: points.map(\.dayKey)) { _, _ in
            guard let selectedDate else { return }
            if ChartDaySelection.nearestPoint(to: selectedDate, in: points) == nil {
                self.selectedDate = defaultSelectedDate
            }
        }
        .onChange(of: selectedDate) { _, newValue in
            guard allowsScroll, let newValue else { return }
            scrollDate = scrollAnchor(for: newValue)
        }
    }

    private func scrollAnchor(for date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -(max(visibleDays, 1) / 2), to: date) ?? date
    }

    private func daySummary(_ point: DayExplorePoint) -> String {
        let date = point.date.formatted(date: .abbreviated, time: .omitted)
        return "\(date). \(LaneScrubReadout.line(point: point))."
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
            .allowsHitTesting(false)
            .overlay {
                #if canImport(UIKit)
                HorizontalDayScrub { location in
                    select(at: location.x, width: width)
                }
                #endif
            }
        }
        .frame(height: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(ProgressChartAccessibility.scrubber)
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
            Text(LaneScrubReadout.line(point: point))
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
        .accessibilityIdentifier(ProgressChartAccessibility.readout)
        .accessibilityLabel(scrubLabel)
    }

    private var scrubLabel: String {
        let date = point.date.formatted(date: .abbreviated, time: .omitted)
        return "\(date). \(LaneScrubReadout.line(point: point))."
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

// MARK: - Three charts

private enum ProgressChartMetric: Equatable {
    case pain
    case load
    case steps

    var title: String {
        switch self {
        case .pain: return "Pain"
        case .load: return "Load"
        case .steps: return "Steps"
        }
    }

    var unit: String? {
        switch self {
        case .pain: return "0–10"
        case .load: return "lb"
        case .steps: return nil
        }
    }

    var color: Color {
        switch self {
        case .pain: return ExplorePalette.pain
        case .load: return ExplorePalette.load
        case .steps: return ExplorePalette.steps
        }
    }

    var showsDateAxis: Bool { self == .steps }

    var stroke: StrokeStyle {
        switch self {
        case .pain, .load:
            return StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
        case .steps:
            return StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [0.8, 3.2])
        }
    }

    func samples(_ points: [DayExplorePoint]) -> [ExploreSample] {
        switch self {
        case .pain:
            return ExploreSeries.continuousSamples(points, value: \.pain)
        case .load:
            return ExploreSeries.continuousSamples(points, value: \.loadLbs)
        case .steps:
            return ExploreSeries.continuousSamples(points, value: \.steps)
        }
    }
}

private struct ProgressMetricChart: View {
    var metric: ProgressChartMetric
    let points: [DayExplorePoint]
    var visibleDays: Int
    var allowsScroll: Bool
    var domain: ClosedRange<Date>
    var axisDates: [Date]
    @Binding var selectedDate: Date?
    @Binding var scrollDate: Date

    private var samples: [ExploreSample] {
        metric.samples(points)
    }

    private var yDomain: ClosedRange<Double> {
        switch metric {
        case .pain:
            return 0...10
        case .load, .steps:
            let peak = samples.map(\.value).max() ?? 0
            return 0...axisTop(for: peak)
        }
    }

    private var yTicks: [Double] {
        switch metric {
        case .pain:
            return [0, 5, 10]
        case .load, .steps:
            let top = yDomain.upperBound
            return [0, top / 2, top]
        }
    }

    private var labeledDayKeys: Set<String> {
        guard metric == .load else { return [] }
        let indexes = points.enumerated().compactMap { index, point -> Int? in
            guard point.loadLbs != nil, let label = point.repLabel, !label.isEmpty else { return nil }
            return index
        }
        let shown = RepLabelVisibility.shown(sessionDayIndexes: indexes, dayCount: points.count)
        return Set(shown.map { points[$0].dayKey })
    }

    private var repLabelFont: Font {
        if points.count > 10 {
            return .system(size: 8, weight: .semibold)
        }
        return .caption2.weight(.bold)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(metric.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(metric.color)
                if let unit = metric.unit {
                    Text(unit)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            chart
                .frame(height: metric.showsDateAxis ? 156 : 128)
                .accessibilityHidden(true)
        }
        .padding(CGFloat(ExploreAxisLayout.chartCardPadding / 2))
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private var chart: some View {
        Chart {
            ForEach(axisDates, id: \.timeIntervalSinceReferenceDate) { date in
                RuleMark(x: .value("Day", date))
                    .foregroundStyle(Color.white.opacity(0.10))
            }
            ForEach(samples) { sample in
                LineMark(
                    x: .value("Day", sample.date),
                    y: .value(metric.title, sample.value)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(metric.color)
                .lineStyle(metric.stroke)
            }
            seriesPoints
            if let selected = selectedDate.flatMap({ ChartDaySelection.nearestPoint(to: $0, in: points) }) {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(AppTheme.gold.opacity(0.95))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: domain)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks) { value in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(yLabel(number))
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: CGFloat(ExploreAxisLayout.yAxisWidth) - 8, alignment: .trailing)
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .chartPlotStyle { plot in
            plot.padding(.bottom, metric.showsDateAxis ? 22 : 0)
        }
        .modifier(ExploreScrollModifier(visibleDays: visibleDays, enabled: allowsScroll, scrollDate: $scrollDate))
        .chartOverlay { proxy in
            GeometryReader { geo in
                ZStack {
                    if metric.showsDateAxis {
                        dateLabels(proxy: proxy, geo: geo)
                    }
                    if !allowsScroll {
                        #if canImport(UIKit)
                        HorizontalDayScrub { location in
                            select(at: location, proxy: proxy, geo: geo)
                        }
                        #endif
                    }
                }
                .allowsHitTesting(!allowsScroll)
                .preference(key: PlotInsetsKey.self, value: insets(proxy: proxy, geo: geo))
            }
        }
    }

    @ChartContentBuilder
    private var seriesPoints: some ChartContent {
        if metric == .load {
            ForEach(points) { point in
                if let load = point.loadLbs {
                    PointMark(
                        x: .value("Day", point.date),
                        y: .value("Load", load)
                    )
                    .foregroundStyle(ExplorePalette.load)
                    .symbolSize(36)
                    .annotation(position: .top, spacing: 2) {
                        if let label = point.repLabel, labeledDayKeys.contains(point.dayKey) {
                            Text(label)
                                .font(repLabelFont)
                                .foregroundStyle(ExplorePalette.load)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                }
            }
        } else if samples.count == 1, let only = samples.first {
            PointMark(
                x: .value("Day", only.date),
                y: .value(metric.title, only.value)
            )
            .foregroundStyle(metric.color)
            .symbolSize(28)
        }
    }

    private func dateLabels(proxy: ChartProxy, geo: GeometryProxy) -> some View {
        let half = CGFloat(ExploreAxisLayout.dateLabelWidth) / 2
        return ZStack {
            if let plotFrame = proxy.plotFrame {
                let plot = geo[plotFrame]
                ForEach(axisDates, id: \.timeIntervalSinceReferenceDate) { date in
                    if let x = proxy.position(forX: date), x - half >= 0, x + half <= plot.width {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize()
                            .position(x: plot.minX + x, y: plot.maxY + 12)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func insets(proxy: ChartProxy, geo: GeometryProxy) -> PlotInsets {
        guard metric.showsDateAxis, let plotFrame = proxy.plotFrame else {
            return PlotInsets(
                leading: CGFloat(ExploreAxisLayout.yAxisWidth),
                trailing: CGFloat(ExploreAxisLayout.plotTrailingPadding)
            )
        }
        let plot = geo[plotFrame]
        return PlotInsets(
            leading: plot.minX,
            trailing: max(0, geo.size.width - plot.maxX)
        )
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

    private func yLabel(_ value: Double) -> String {
        switch metric {
        case .pain:
            return String(Int(value.rounded()))
        case .load:
            return LaneScrubReadout.formatLoad(value)
        case .steps:
            return compactCount(value)
        }
    }

    private func compactCount(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(rounded) < 1000 {
            return String(Int(rounded))
        }
        let thousands = rounded / 1000
        if abs(thousands.rounded() - thousands) < 0.05 {
            return "\(Int(thousands.rounded()))k"
        }
        return String(format: "%.1fk", thousands)
    }

    private func axisTop(for peak: Double) -> Double {
        let raw = max(peak * 1.35, 1)
        let step: Double
        switch raw {
        case ..<10: step = 2
        case ..<40: step = 5
        case ..<100: step = 10
        case ..<400: step = 50
        case ..<2000: step = 100
        case ..<20000: step = 1000
        default: step = 5000
        }
        return ceil(raw / step) * step
    }
}

private struct PlotInsets: Equatable {
    var leading: CGFloat
    var trailing: CGFloat
}

private struct PlotInsetsKey: PreferenceKey {
    static var defaultValue = PlotInsets(
        leading: CGFloat(ExploreAxisLayout.yAxisWidth),
        trailing: CGFloat(ExploreAxisLayout.plotTrailingPadding)
    )

    static func reduce(value: inout PlotInsets, nextValue: () -> PlotInsets) {
        let next = nextValue()
        // Only the steps chart publishes the real plot frame. The other two
        // repeat the placeholder, which would otherwise wipe the measurement.
        if next.leading != defaultValue.leading || next.trailing != defaultValue.trailing {
            value = next
        }
    }
}

private struct ExploreScrollModifier: ViewModifier {
    var visibleDays: Int
    var enabled: Bool
    @Binding var scrollDate: Date

    func body(content: Content) -> some View {
        if enabled {
            content
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: TimeInterval(visibleDays) * 24 * 60 * 60)
                .chartScrollPosition(x: $scrollDate)
        } else {
            content
        }
    }
}

#if canImport(UIKit)
/// Horizontal pans scrub the shared day. A vertical pan fails immediately so the
/// page scroll view can take it.
private struct HorizontalDayScrub: UIViewRepresentable {
    var onSelect: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onSelect = onSelect
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onSelect: (CGPoint) -> Void

        init(onSelect: @escaping (CGPoint) -> Void) {
            self.onSelect = onSelect
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            switch gesture.state {
            case .began, .changed:
                onSelect(gesture.location(in: view))
            default:
                break
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let view = gesture.view else { return }
            onSelect(gesture.location(in: view))
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}
#endif

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
