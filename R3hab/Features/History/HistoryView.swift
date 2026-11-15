import SwiftData
import SwiftUI

/// Past sessions, the load from each exercise, and a short trend.
struct SessionLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]

    @State private var pendingDelete: SessionLogEntry?

    private var days: [SessionLogDay] {
        SessionLogBuilder.days(from: sessions.map(\.snapshot))
    }

    private var workingTrend: [LoadTrendPoint] {
        SessionLogBuilder.workingSetTrend(from: days)
    }

    private var holdTrend: [LoadTrendPoint] {
        SessionLogBuilder.isometricTrend(from: days)
    }

    var body: some View {
        NavigationStack {
            Group {
                if days.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .appCanvas()
            .navigationTitle("Log")
            .accessibilityIdentifier("session-log")
            .alert(
                "Delete this entry?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                presenting: pendingDelete
            ) { entry in
                Button("Delete", role: .destructive) { delete(entry) }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: { entry in
                Text("\(entry.title) will be removed from this day.")
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No sessions yet")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.ivory)
            Text("Sessions you save show up here, with their load.")
                .font(.body)
                .foregroundStyle(AppTheme.quiet)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            if !workingTrend.isEmpty || !holdTrend.isEmpty {
                Section {
                    if !workingTrend.isEmpty {
                        LoadTrendChart(
                            title: "Working sets",
                            unit: "lb",
                            points: workingTrend
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    }
                    if !holdTrend.isEmpty {
                        LoadTrendChart(
                            title: "Isometric holds",
                            unit: "lb·s",
                            points: holdTrend
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    }
                }
            }

            ForEach(days) { day in
                Section {
                    ForEach(day.entries) { entry in
                        entryRow(entry)
                            .listRowBackground(AppTheme.canvas)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    pendingDelete = entry
                                }
                            }
                    }
                } header: {
                    dayHeader(day)
                }
            }

            Section {
                Text(SessionLogBuilder.formulaNote)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.quiet)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func dayHeader(_ day: SessionLogDay) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayTitle(day.day))
                    .font(.headline)
                    .foregroundStyle(AppTheme.ivory)
                if let steps = SessionSteps.label(day.steps) {
                    Text(steps)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(AppTheme.quiet)
                        .accessibilityIdentifier("session-log-day-steps")
                }
            }
            Spacer()
            if let summary = TrainingLoad.summary(poundReps: day.poundReps, poundSeconds: day.poundSeconds) {
                Text(summary)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.gold)
            }
        }
        .textCase(nil)
        .padding(.top, 8)
    }

    private func entryRow(_ entry: SessionLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.ivory)
            if entry.setLines.isEmpty, let dose = entry.dose, !dose.isEmpty {
                Text(dose)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.quiet)
            } else {
                ForEach(Array(entry.setLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.quiet)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if !entry.pain.isEmpty {
                    Text(entry.pain)
                        .foregroundStyle(AppTheme.quiet)
                }
                Spacer(minLength: 0)
                if let load = TrainingLoad.summary(poundReps: entry.poundReps, poundSeconds: entry.poundSeconds) {
                    Text(load)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(AppTheme.ivory)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("session-log-entry")
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func delete(_ entry: SessionLogEntry) {
        guard let row = sessions.first(where: { $0.id == entry.id }) else { return }
        modelContext.delete(row)
        try? modelContext.save()
        pendingDelete = nil
    }
}

/// Vertical bars for the last few days that have a load. Oldest on the left.
struct LoadTrendChart: View {
    var title: String
    var unit: String
    var points: [LoadTrendPoint]

    private var peak: Double {
        max(points.map(\.value).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.quiet)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(points) { point in
                    VStack(spacing: 6) {
                        Text(TrainingLoad.formatted(point.value))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(AppTheme.ivory)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(AppTheme.gold)
                            .frame(height: max(8, 72 * point.value / peak))
                        Text(point.day.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.quiet)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(point.day.formatted(date: .abbreviated, time: .omitted)), \(TrainingLoad.formatted(point.value)) \(unit)")
                }
            }
            .frame(height: 120, alignment: .bottom)
        }
        .padding(14)
        .posterCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(title == "Working sets" ? "trend-working-sets" : "trend-isometric-holds")
    }
}

#Preview {
    SessionLogView()
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
