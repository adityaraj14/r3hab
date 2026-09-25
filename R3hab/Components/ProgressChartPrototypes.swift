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

/// Pain band, working load in lb, and step points.
struct KneeExploreChart: View {
    let points: [DayExplorePoint]
    var height: CGFloat = 168
    var visibleDays: Int = 7
    var emptyDescription: String = "Log morning or evening pain, steps, or a session. The chart reads the days you actually logged."

    @State private var selectedDate: Date?

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
                RibbonExplorePlot(
                    points: points,
                    visibleDays: visibleDays,
                    selectedDate: $selectedDate
                )
                .frame(height: max(height, 156))
                .accessibilityLabel("Pain as a soft band, working load in lb, steps as points.")
                if let selected {
                    ExploreScrubber(
                        points: points,
                        selectedDate: $selectedDate,
                        leadingInset: 12,
                        trailingInset: 12,
                        summary: daySummary(selected)
                    )
                    ExploreDayReadout(point: selected)
                }
                Text("Drag the scrubber. Pain, load, and steps for that day.")
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
        return RibbonDayReadout.summary(point: point, date: date)
    }
}

private struct ExploreLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            item(ExplorePalette.pain, "Pain", accessibility: "Pain")
            item(ExplorePalette.load, "Load", accessibility: "Load")
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
            if !RibbonDayReadout.hasData(point) {
                Text(RibbonDayReadout.noData)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    metric("Pain", RibbonDayReadout.pain(point.pain), ExplorePalette.pain)
                    metric("Load", RibbonDayReadout.load(point.loadLbs), ExplorePalette.load)
                    metric("Steps", RibbonDayReadout.steps(point.steps), ExplorePalette.steps)
                }
            }
            ExploreDayDetails(point: point)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            RibbonDayReadout.summary(
                point: point,
                date: point.date.formatted(date: .abbreviated, time: .omitted)
            )
        )
    }

    private func metric(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(color)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ExploreDayDetails: View {
    let point: DayExplorePoint

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if point.morningPain != nil || point.eveningPain != nil {
                Text("Morning \(RibbonDayReadout.pain(point.morningPain)) · Evening \(RibbonDayReadout.pain(point.eveningPain))")
            }
            if point.duringPain != nil || point.afterPain != nil {
                Text("During \(RibbonDayReadout.pain(point.duringPain)) · After \(RibbonDayReadout.pain(point.afterPain))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Ribbon

private struct RibbonExplorePlot: View {
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
            painMarks
            loadMarks
            stepMarks
            if let selected = selectedDate.flatMap({ ChartDaySelection.nearestPoint(to: $0, in: points) }) {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(AppTheme.gold.opacity(0.95))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartYScale(domain: 0...1)
        .chartYAxis(.hidden)
        .chartXScale(domain: xDomain)
        .chartLegend(.hidden)
        .chartPlotStyle { plot in
            plot.padding(.horizontal, 4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xStride)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
    }

    @ChartContentBuilder
    private var painMarks: some ChartContent {
        let segments = ExploreSeries.contiguousSegments(points, value: \.pain)
        ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
            ForEach(segment) { point in
                if let pain = point.pain {
                    AreaMark(
                        x: .value("Day", point.date),
                        y: .value("Pain", pain / 10),
                        series: .value("Pain band", "pain-\(index)"),
                        stacking: .unstacked
                    )
                    .interpolationMethod(segment.count >= 3 ? .catmullRom : .linear)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.gold.opacity(0.5), AppTheme.gold.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("Pain", pain / 10),
                        series: .value("Pain line", "pain-\(index)")
                    )
                    .interpolationMethod(segment.count >= 3 ? .catmullRom : .linear)
                    .foregroundStyle(ExplorePalette.pain)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
        }
    }

    @ChartContentBuilder
    private var loadMarks: some ChartContent {
        let segments = ExploreSeries.contiguousSegments(points, value: \.loadLbs)
        ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
            ForEach(segment) { point in
                if let load = point.loadLbs,
                   let unit = ExploreSignalScale.unit(load, peak: loadPeak) {
                    LineMark(
                        x: .value("Day", point.date),
                        y: .value("Load", unit),
                        series: .value("Load", "load-\(index)")
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(ExplorePalette.load.opacity(0.85))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                }
            }
            ForEach(segment) { point in
                if let load = point.loadLbs, !point.loadCarried,
                   let unit = ExploreSignalScale.unit(load, peak: loadPeak) {
                    PointMark(
                        x: .value("Day", point.date),
                        y: .value("Load", unit)
                    )
                    .foregroundStyle(ExplorePalette.load)
                    .symbolSize(36)
                    .annotation(position: .top, spacing: 2) {
                        Text(LoadCopy.formatted(load))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(ExplorePalette.load)
                    }
                }
            }
        }
    }

    @ChartContentBuilder
    private var stepMarks: some ChartContent {
        ForEach(RibbonSeries.stepDays(points)) { point in
            if let steps = point.steps,
               let unit = ExploreSignalScale.unit(steps, peak: stepsPeak) {
                PointMark(
                    x: .value("Day", point.date),
                    y: .value("Steps", max(unit, 0.04))
                )
                .foregroundStyle(ExplorePalette.steps)
                .symbolSize(28)
            }
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
                .chartXVisibleDomain(length: TimeInterval(visibleDays) * 24 * 60 * 60 + 12 * 60 * 60)
                .chartScrollPosition(x: $scrollDate)
        } else {
            content
        }
    }
}

/// Tap, and drag when the chart itself is not scrolling, so a day can be chosen on the ribbon.
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

#Preview {
    ExploreStylePreview()
        .preferredColorScheme(.dark)
}

private struct ExploreStylePreview: View {
    var body: some View {
        ScrollView {
            KneeExploreChart(
                points: ExplorePreviewData.points,
                visibleDays: 7
            )
            .padding()
        }
        .background(Color.black)
    }
}

private enum ExplorePreviewData {
    static var points: [DayExplorePoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let pains: [Double?] = [3, 2, nil, 4, 3.5, 2, 1]
        let volumes: [Double?] = [nil, 800, nil, 1200, nil, 960, 1400]
        let steps: [Double?] = [4200, 6100, 0, nil, 7300, 5400, 8000]
        return pains.indices.map { index in
            let date = calendar.date(byAdding: .day, value: index - 6, to: today)!
            return DayExplorePoint(
                dayKey: CalendarDay.dayKey(date),
                date: date,
                pain: pains[index],
                volume: volumes[index],
                steps: steps[index]
            )
        }
    }
}
