import SwiftUI
import Charts

/// Colors for the combined pain / load / steps prototypes. Dark canvas, one gold accent.
enum ExplorePalette {
    static let pain = AppTheme.gold
    static let volume = Color.white.opacity(0.72)
    static let steps = Color(red: 0.62, green: 0.86, blue: 1.0)
    static let track = Color.white.opacity(0.08)
}

enum ExploreDayFormat {
    static func pain(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value.rounded() == value {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    static func steps(_ value: Double?) -> String {
        guard let value else { return "—" }
        return Int(value.rounded()).formatted()
    }

    static func volume(_ value: Double?) -> String {
        value.map(VolumeCopy.labeled) ?? "—"
    }

    static func summary(point: DayExplorePoint, volumeTitle: String) -> String {
        let date = point.date.formatted(date: .abbreviated, time: .omitted)
        return "\(date). Pain \(pain(point.pain)). \(volumeTitle) \(volume(point.volume)). Steps \(steps(point.steps))."
    }
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

/// Prototype picker. The raw id lives in UserDefaults so a relaunch keeps Adi's pick.
struct ExploreStylePicker: View {
    @Binding var raw: String

    private var style: ProgressChartStyle {
        ProgressChartStyle.resolved(raw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ProgressChartStyle.allCases) { candidate in
                        let selected = candidate == style
                        Button {
                            raw = candidate.rawValue
                        } label: {
                            Text(candidate.pickerTitle)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(selected ? AppTheme.gold : Color.white.opacity(0.08))
                                )
                                .foregroundStyle(selected ? AppTheme.ink : Color.white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("progress-chart-style-\(candidate.rawValue)")
                        .accessibilityLabel("\(candidate.pickerTitle). \(candidate.intent)")
                        .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : AccessibilityTraits())
                    }
                }
            }
            .accessibilityIdentifier("progress-chart-style")
            .accessibilityLabel("Chart style")

            Text(style.intent)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One combined pain + load + steps chart. Style changes the drawing, not the day model.
struct KneeExploreChart: View {
    let points: [DayExplorePoint]
    var height: CGFloat = 168
    var visibleDays: Int = 7
    var volumeTitle: String = "Volume"
    var emptyDescription: String = "Log morning or evening pain, steps, or a session. The chart reads the days you actually logged."
    var style: ProgressChartStyle = .ribbon

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

    private var plotHeight: CGFloat {
        switch style {
        case .ribbon: return max(height, 156)
        case .orbit: return 136
        case .heatlane: return 132
        case .glassDial: return 196
        case .emberTide: return max(height, 160)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasData {
                ExploreLegend(volumeTitle: volumeTitle)
                plot
                    .frame(height: plotHeight)
                    .accessibilityLabel("\(style.pickerTitle). \(style.intent)")
                if style != .ribbon && style != .glassDial {
                    ExploreDateAxis(points: points)
                }
                if let selected {
                    ExploreScrubber(
                        points: points,
                        selectedDate: $selectedDate,
                        leadingInset: scrubLeading,
                        trailingInset: 12,
                        summary: ExploreDayFormat.summary(point: selected, volumeTitle: volumeTitle)
                    )
                }
                if style == .glassDial, let selected {
                    ExploreDayDetails(point: selected)
                } else if let selected {
                    ExploreDayReadout(point: selected, volumeTitle: volumeTitle)
                }
                Text("Drag the scrubber. Pain, \(volumeTitle.lowercased()), and steps for that day.")
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

    private var scrubLeading: CGFloat {
        style == .heatlane ? HeatLanePlot.labelWidth : 12
    }

    @ViewBuilder
    private var plot: some View {
        switch style {
        case .ribbon:
            RibbonExplorePlot(
                points: points,
                visibleDays: visibleDays,
                selectedDate: $selectedDate
            )
        case .orbit:
            ExplorePlotViewport(
                points: points,
                visibleDays: visibleDays,
                minDayWidth: 36,
                leadingInset: 12,
                trailingInset: 12,
                selectedDate: $selectedDate
            ) {
                OrbitPlot(points: points, selectedDayKey: selected?.dayKey)
            }
        case .heatlane:
            ExplorePlotViewport(
                points: points,
                visibleDays: visibleDays,
                minDayWidth: nil,
                leadingInset: HeatLanePlot.labelWidth,
                trailingInset: 12,
                selectedDate: $selectedDate
            ) {
                HeatLanePlot(points: points)
            }
        case .glassDial:
            GlassDialPlot(points: points, volumeTitle: volumeTitle, selectedDate: $selectedDate)
        case .emberTide:
            ExplorePlotViewport(
                points: points,
                visibleDays: visibleDays,
                minDayWidth: nil,
                leadingInset: 12,
                trailingInset: 12,
                selectedDate: $selectedDate
            ) {
                EmberTidePlot(points: points, selectedDayKey: selected?.dayKey)
            }
        }
    }
}

private struct ExploreLegend: View {
    var volumeTitle: String

    var body: some View {
        HStack(spacing: 14) {
            item(ExplorePalette.pain, "Pain", accessibility: "Pain")
            item(ExplorePalette.volume, "Load", accessibility: volumeTitle)
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

private struct ExploreDateAxis: View {
    let points: [DayExplorePoint]

    var body: some View {
        HStack {
            Text(label(points.first?.date))
            Spacer()
            Text(label(points.count > 2 ? points[points.count / 2].date : nil))
            Spacer()
            Text(label(points.last?.date))
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
    }

    private func label(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(.dateTime.month(.abbreviated).day())
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
    var volumeTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(point.date.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline.weight(.semibold))
            HStack(alignment: .top, spacing: 12) {
                metric("Pain", ExploreDayFormat.pain(point.pain), ExplorePalette.pain)
                metric(volumeTitle, ExploreDayFormat.volume(point.volume), ExplorePalette.volume)
                metric("Steps", ExploreDayFormat.steps(point.steps), ExplorePalette.steps)
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
        .accessibilityLabel(ExploreDayFormat.summary(point: point, volumeTitle: volumeTitle))
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
                Text("Morning \(ExploreDayFormat.pain(point.morningPain)) · Evening \(ExploreDayFormat.pain(point.eveningPain))")
            }
            if point.duringPain != nil || point.afterPain != nil {
                Text("During \(ExploreDayFormat.pain(point.duringPain)) · After \(ExploreDayFormat.pain(point.afterPain))")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Viewport

/// Fits the series, or scrolls once a day would be thinner than the range viewport / minimum.
private struct ExplorePlotViewport<Content: View>: View {
    let points: [DayExplorePoint]
    var visibleDays: Int
    var minDayWidth: CGFloat?
    var leadingInset: CGFloat
    var trailingInset: CGFloat
    @Binding var selectedDate: Date?
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let contentWidth = contentWidth(viewport: width)
            let scrolls = contentWidth > width + 1
            Group {
                if scrolls {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            framed(contentWidth, height: geo.size.height, allowDrag: false)
                        }
                        .onAppear { scroll(proxy, to: selectedDate) }
                        .onChange(of: selectedDate) { _, newValue in
                            scroll(proxy, to: newValue)
                        }
                    }
                } else {
                    framed(width, height: geo.size.height, allowDrag: true)
                }
            }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, to date: Date?) {
        let key = date.flatMap { ChartDaySelection.nearestPoint(to: $0, in: points)?.dayKey } ?? points.last?.dayKey
        guard let key else { return }
        proxy.scrollTo(key, anchor: .center)
    }

    private func framed(_ width: CGFloat, height: CGFloat, allowDrag: Bool) -> some View {
        content()
            .frame(width: width, height: height)
            .background(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(points) { point in
                        Color.clear
                            .frame(width: width / CGFloat(max(points.count, 1)))
                            .id(point.dayKey)
                    }
                }
            }
            .overlay {
                cursor(width: width, height: height)
            }
            .overlay {
                gestureLayer(width: width, allowDrag: allowDrag)
            }
    }

    private func contentWidth(viewport: CGFloat) -> CGFloat {
        let count = CGFloat(max(points.count, 1))
        let window = CGFloat(max(min(points.count, visibleDays), 1))
        var day = viewport / window
        if points.count <= visibleDays {
            day = viewport / count
        }
        if let minDayWidth {
            day = max(day, minDayWidth)
        }
        return day * count
    }

    @ViewBuilder
    private func cursor(width: CGFloat, height: CGFloat) -> some View {
        if let date = selectedDate {
            let x = ExplorePlotMetrics.x(
                for: date,
                in: points,
                width: width,
                leading: leadingInset,
                trailing: trailingInset
            )
            Rectangle()
                .fill(AppTheme.gold.opacity(0.9))
                .frame(width: 1.5, height: height)
                .position(x: x, y: height / 2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func gestureLayer(width: CGFloat, allowDrag: Bool) -> some View {
        let base = Color.clear
            .contentShape(Rectangle())
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { event in
                        assign(day(at: event.location.x, width: width))
                    }
            )
        if allowDrag {
            base.simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        assign(day(at: value.location.x, width: width))
                    }
            )
        } else {
            base
        }
    }

    private func day(at locationX: CGFloat, width: CGFloat) -> DayExplorePoint? {
        ExplorePlotMetrics.point(
            at: locationX,
            width: width,
            leading: leadingInset,
            trailing: trailingInset,
            points: points
        )
    }

    private func assign(_ point: DayExplorePoint?) {
        guard let point, selectedDate != point.date else { return }
        Haptics.light()
        selectedDate = point.date
    }
}

// MARK: - Ribbon

private struct RibbonExplorePlot: View {
    let points: [DayExplorePoint]
    var visibleDays: Int
    @Binding var selectedDate: Date?

    private var calendar: Calendar { .current }

    private var volumePeak: Double {
        ExploreSignalScale.peak(points.map(\.volume))
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
            volumeMarks
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
    private var volumeMarks: some ChartContent {
        ForEach(points) { point in
            if let volume = point.volume,
               let unit = ExploreSignalScale.unit(volume, peak: volumePeak) {
                BarMark(
                    x: .value("Day", point.date),
                    y: .value("Load", unit * 0.38),
                    stacking: .unstacked
                )
                .foregroundStyle(Color.white.opacity(0.28))
                .cornerRadius(2)
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
                        y: .value("Steps", unit),
                        series: .value("Steps", "steps-\(index)")
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(ExplorePalette.steps)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    PointMark(
                        x: .value("Day", point.date),
                        y: .value("Steps", unit)
                    )
                    .foregroundStyle(ExplorePalette.steps)
                    .symbolSize(22)
                }
            }
        }
    }
}

// MARK: - Orbit

private struct OrbitPlot: View {
    let points: [DayExplorePoint]
    var selectedDayKey: String?

    var body: some View {
        Canvas { context, size in
            let volumePeak = ExploreSignalScale.peak(points.map(\.volume))
            let stepsPeak = ExploreSignalScale.peak(points.map(\.steps))
            let plotWidth = ExplorePlotMetrics.plotWidth(width: size.width, leading: 12, trailing: 12)
            let gap = points.count > 1 ? plotWidth / CGFloat(points.count - 1) : plotWidth
            for point in points {
                let selected = point.dayKey == selectedDayKey
                let center = CGPoint(
                    x: ExplorePlotMetrics.x(for: point.date, in: points, width: size.width, leading: 12, trailing: 12),
                    y: size.height * 0.52
                )
                let outer = min(gap * 0.34, size.height * 0.32) * (selected ? 1.12 : 1)
                if selected {
                    let glow = Path(
                        ellipseIn: CGRect(
                            x: center.x - outer - 5,
                            y: center.y - outer - 5,
                            width: (outer + 5) * 2,
                            height: (outer + 5) * 2
                        )
                    )
                    context.fill(glow, with: .color(AppTheme.gold.opacity(0.14)))
                }
                ring(context: &context, center: center, radius: outer, unit: point.pain.map { $0 / 10 }, color: ExplorePalette.pain, width: selected ? 3 : 2)
                ring(
                    context: &context,
                    center: center,
                    radius: outer * 0.68,
                    unit: ExploreSignalScale.unit(point.volume, peak: volumePeak),
                    color: ExplorePalette.volume,
                    width: selected ? 2.5 : 1.5
                )
                ring(
                    context: &context,
                    center: center,
                    radius: outer * 0.38,
                    unit: ExploreSignalScale.unit(point.steps, peak: stepsPeak),
                    color: ExplorePalette.steps,
                    width: selected ? 2.5 : 1.5
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func ring(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        unit: Double?,
        color: Color,
        width: CGFloat
    ) {
        var guide = Path()
        guide.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(230),
            clockwise: false
        )
        context.stroke(guide, with: .color(color.opacity(0.16)), lineWidth: width)
        guard let unit else { return }
        let sweep = unit <= 0 ? 8 : unit * 320
        var arc = Path()
        arc.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + sweep),
            clockwise: false
        )
        context.stroke(arc, with: .color(color), lineWidth: width)
    }
}

// MARK: - Heatlane

private struct HeatLanePlot: View {
    static let labelWidth: CGFloat = 52

    let points: [DayExplorePoint]

    var body: some View {
        Canvas { context, size in
            let volumePeak = ExploreSignalScale.peak(points.map(\.volume))
            let stepsPeak = ExploreSignalScale.peak(points.map(\.steps))
            let lanes: [(String, Color, [Double?])] = [
                ("Pain", ExplorePalette.pain, points.map { $0.pain.map { $0 / 10 } }),
                ("Load", ExplorePalette.volume, points.map { ExploreSignalScale.unit($0.volume, peak: volumePeak) }),
                ("Steps", ExplorePalette.steps, points.map { ExploreSignalScale.unit($0.steps, peak: stepsPeak) })
            ]
            let laneGap: CGFloat = 6
            let laneHeight = (size.height - laneGap * 2) / 3
            let plotWidth = ExplorePlotMetrics.plotWidth(width: size.width, leading: Self.labelWidth, trailing: 12)
            let dayGap = points.count > 1 ? plotWidth / CGFloat(points.count - 1) : plotWidth
            let cellWidth = max(points.count > 1 ? dayGap * 0.84 : min(18, plotWidth), 1)
            for (laneIndex, lane) in lanes.enumerated() {
                let y = CGFloat(laneIndex) * (laneHeight + laneGap)
                context.draw(
                    Text(lane.0)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(lane.1),
                    at: CGPoint(x: 0, y: y + laneHeight / 2),
                    anchor: .leading
                )
                for (dayIndex, unit) in lane.2.enumerated() {
                    let center = ExplorePlotMetrics.x(
                        for: points[dayIndex].date,
                        in: points,
                        width: size.width,
                        leading: Self.labelWidth,
                        trailing: 12
                    )
                    let rect = clampedRect(
                        centerX: center,
                        width: cellWidth,
                        y: y,
                        height: laneHeight,
                        minX: Self.labelWidth,
                        maxX: size.width - 12
                    )
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: min(3, cellWidth / 2)),
                        with: .color(cellColor(unit: unit, tint: lane.1))
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func cellColor(unit: Double?, tint: Color) -> Color {
        guard let unit else { return Color.white.opacity(0.04) }
        return tint.opacity(0.16 + 0.84 * unit)
    }

    private func clampedRect(
        centerX: CGFloat,
        width: CGFloat,
        y: CGFloat,
        height: CGFloat,
        minX: CGFloat,
        maxX: CGFloat
    ) -> CGRect {
        var x = centerX - width / 2
        var cellWidth = width
        if x < minX {
            cellWidth -= minX - x
            x = minX
        }
        if x + cellWidth > maxX {
            cellWidth = maxX - x
        }
        return CGRect(x: x, y: y, width: max(cellWidth, 1), height: height)
    }
}

// MARK: - Glass dial

private struct GlassDialPlot: View {
    let points: [DayExplorePoint]
    var volumeTitle: String
    @Binding var selectedDate: Date?

    private var point: DayExplorePoint? {
        let target = selectedDate ?? points.last(where: \.hasValues)?.date
        guard let target else { return nil }
        return ChartDaySelection.nearestPoint(to: target, in: points)
    }

    var body: some View {
        ZStack {
            spark
                .opacity(0.55)
                .allowsHitTesting(false)
            if let point {
                VStack(alignment: .leading, spacing: 10) {
                    Text(point.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                    HStack(alignment: .top, spacing: 10) {
                        dial("Pain", ExploreDayFormat.pain(point.pain), ExplorePalette.pain)
                        dial(volumeTitle, ExploreDayFormat.volume(point.volume), Color.white)
                        dial("Steps", ExploreDayFormat.steps(point.steps), ExplorePalette.steps)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(ExploreDayFormat.summary(point: point, volumeTitle: volumeTitle))
                .allowsHitTesting(false)
            }
        }
            .overlay {
            GeometryReader { geo in
                Color.clear
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { event in
                                assign(at: event.location.x, width: geo.size.width)
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { value in
                                assign(at: value.location.x, width: geo.size.width)
                            }
                    )
            }
            .accessibilityHidden(true)
        }
    }

    private func assign(at locationX: CGFloat, width: CGFloat) {
        guard let day = ExplorePlotMetrics.point(
            at: locationX,
            width: width,
            leading: 0,
            trailing: 0,
            points: points
        ), selectedDate != day.date else { return }
        Haptics.light()
        selectedDate = day.date
    }

    private var spark: some View {
        Canvas { context, size in
            let volumePeak = ExploreSignalScale.peak(points.map(\.volume))
            let stepsPeak = ExploreSignalScale.peak(points.map(\.steps))
            stroke(context: &context, size: size, values: points.map { $0.pain.map { $0 / 10 } }, color: ExplorePalette.pain, width: 2)
            stroke(
                context: &context,
                size: size,
                values: points.map { ExploreSignalScale.unit($0.volume, peak: volumePeak) },
                color: Color.white.opacity(0.7),
                width: 1.5
            )
            stroke(
                context: &context,
                size: size,
                values: points.map { ExploreSignalScale.unit($0.steps, peak: stepsPeak) },
                color: ExplorePalette.steps,
                width: 1.5
            )
        }
    }

    private func stroke(
        context: inout GraphicsContext,
        size: CGSize,
        values: [Double?],
        color: Color,
        width: CGFloat
    ) {
        guard points.count > 1 else { return }
        var path = Path()
        var drawing = false
        for (index, value) in values.enumerated() {
            guard let value else {
                drawing = false
                continue
            }
            let x = size.width * CGFloat(index) / CGFloat(points.count - 1)
            let y = size.height - 8 - CGFloat(value) * (size.height - 16)
            let point = CGPoint(x: x, y: y)
            if drawing {
                path.addLine(to: point)
            } else {
                path.move(to: point)
                drawing = true
            }
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    private func dial(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Ember tide

private struct EmberTidePlot: View {
    let points: [DayExplorePoint]
    var selectedDayKey: String?

    var body: some View {
        Canvas { context, size in
            let plotWidth = ExplorePlotMetrics.plotWidth(width: size.width, leading: 12, trailing: 12)
            let dayGap = points.count > 1 ? plotWidth / CGFloat(points.count - 1) : 14
            let columnWidth = max(points.count > 1 ? dayGap * 0.62 : 10, 2)
            let maxH = size.height - 18
            let volumePeak = ExploreSignalScale.peak(points.map(\.volume))
            let stepsPeak = ExploreSignalScale.peak(points.map(\.steps))
            let base = size.height - 8
            for point in points {
                let center = ExplorePlotMetrics.x(for: point.date, in: points, width: size.width, leading: 12, trailing: 12)
                let x = min(max(12, center - columnWidth / 2), size.width - 12 - columnWidth)
                let width = columnWidth
                let stepsUnit = ExploreSignalScale.unit(point.steps, peak: stepsPeak)
                if let stepsUnit {
                    let height = max(stepsUnit == 0 ? 3 : 6, CGFloat(stepsUnit) * maxH)
                    let rect = CGRect(x: x, y: base - height, width: width, height: height)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: min(3, width / 2)),
                        with: .color(emberColor(pain: point.pain, selected: point.dayKey == selectedDayKey))
                    )
                } else if point.pain != nil || point.volume != nil {
                    let rect = CGRect(x: x, y: base - 4, width: width, height: 4)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 1),
                        with: .color(ExplorePalette.pain.opacity(0.55))
                    )
                }
                if let volumeUnit = ExploreSignalScale.unit(point.volume, peak: volumePeak) {
                    let y = base - CGFloat(volumeUnit) * maxH
                    let notch = CGRect(x: x - 1, y: y - 1.5, width: width + 2, height: 3)
                    context.fill(Path(roundedRect: notch, cornerRadius: 1.5), with: .color(AppTheme.gold))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func emberColor(pain: Double?, selected: Bool) -> Color {
        let base: Double
        if let pain {
            base = 0.3 + 0.7 * min(1, max(0, pain / 10))
        } else {
            base = 0.4
        }
        return AppTheme.gold.opacity(selected ? min(1, base + 0.15) : base)
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
    @State private var raw = ProgressChartStyle.ribbon.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ExploreStylePicker(raw: $raw)
                KneeExploreChart(
                    points: ExplorePreviewData.points,
                    visibleDays: 7,
                    volumeTitle: PrimaryLoadCatalog.seatedExtension.chartVolumeTitle,
                    style: ProgressChartStyle.resolved(raw)
                )
            }
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
