import SwiftUI
import SwiftData

/// History — chronological daily + session feed with backdate.
/// Workout rows open SessionEditor. Check-in rows still swipe-delete.
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]

    @State private var filter: Filter = .all
    @State private var editDailyDate: Date?
    @State private var editSessionId: UUID?
    @State private var showBackdate = false
    @State private var backdateKind: BackdateKind = .daily
    @State private var backdateDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var deleteDailyKey: String?
    @State private var pendingBackdateDaily: Date?
    @State private var pendingBackdateSession: Date?

    private var calendar: Calendar { .current }

    enum Filter: String, CaseIterable, Identifiable, Hashable {
        case all, sessions
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "All"
            case .sessions: return "Workouts"
            }
        }
    }

    enum BackdateKind: String, CaseIterable, Identifiable {
        case daily, session
        var id: String { rawValue }
        var title: String {
            switch self {
            case .daily: return "Check-in"
            case .session: return "Workout"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { f in
                        Text(f.title).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(AppTheme.canvas)

                TabView(selection: $filter) {
                    allList
                        .tag(Filter.all)
                    workoutsList
                        .tag(Filter.sessions)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .appCanvas()
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Add a past check-in") {
                            backdateKind = .daily
                            backdateDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                            showBackdate = true
                        }
                        Button("Add a past workout") {
                            backdateKind = .session
                            backdateDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                            showBackdate = true
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .accessibilityLabel("Add a past day")
                    .tint(AppTheme.quiet)
                }
            }
            .sheet(isPresented: Binding(
                get: { editDailyDate != nil },
                set: { if !$0 { editDailyDate = nil } }
            )) {
                if let date = editDailyDate {
                    NavigationStack {
                        DailyCheckInEditor(targetDate: date)
                    }
                    .preferredColorScheme(.dark)
                }
            }
            .sheet(isPresented: Binding(
                get: { editSessionId != nil },
                set: { if !$0 { editSessionId = nil } }
            )) {
                if let id = editSessionId {
                    NavigationStack {
                        SessionEditor(existingId: id)
                    }
                    .preferredColorScheme(.dark)
                }
            }
            .sheet(isPresented: $showBackdate) {
                NavigationStack {
                    Form {
                        Picker("Type", selection: $backdateKind) {
                            ForEach(BackdateKind.allCases) { k in
                                Text(k.title).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)
                        DatePicker(
                            "Date",
                            selection: $backdateDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                    }
                    .navigationTitle("Add a past day")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showBackdate = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Continue") {
                                showBackdate = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    switch backdateKind {
                                    case .daily:
                                        pendingBackdateDaily = calendar.startOfDay(for: backdateDate)
                                    case .session:
                                        pendingBackdateSession = calendar.startOfDay(for: backdateDate)
                                    }
                                }
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
                .preferredColorScheme(.dark)
            }
            .sheet(isPresented: Binding(
                get: { pendingBackdateDaily != nil },
                set: { if !$0 { pendingBackdateDaily = nil } }
            )) {
                if let d = pendingBackdateDaily {
                    NavigationStack {
                        DailyCheckInEditor(targetDate: d)
                    }
                    .preferredColorScheme(.dark)
                }
            }
            .sheet(isPresented: Binding(
                get: { pendingBackdateSession != nil },
                set: { if !$0 { pendingBackdateSession = nil } }
            )) {
                if let d = pendingBackdateSession {
                    NavigationStack {
                        SessionEditor(
                            targetDate: d,
                            focus: .kneeResistance
                        )
                    }
                    .preferredColorScheme(.dark)
                }
            }
            .confirmationDialog(
                "Delete this check-in?",
                isPresented: Binding(
                    get: { deleteDailyKey != nil },
                    set: { if !$0 { deleteDailyKey = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let key = deleteDailyKey,
                       let row = checkIns.first(where: { $0.dayKey == key }) {
                        modelContext.delete(row)
                        try? modelContext.save()
                        Haptics.warning()
                    }
                    deleteDailyKey = nil
                }
                Button("Cancel", role: .cancel) { deleteDailyKey = nil }
            }
        }
    }

    private var allList: some View {
        List {
            ForEach(dayEntries) { day in
                Button {
                    editDailyDate = day.date
                } label: {
                    daySummaryRow(day)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if day.checkIn != nil {
                        Button(role: .destructive) {
                            deleteDailyKey = day.dayKey
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .overlay {
            if dayEntries.isEmpty {
                emptyState(title: "No days yet", description: "Each day will show morning pain, evening pain, steps, and whether you trained. Use + to backdate.")
            }
        }
    }

    private var workoutsList: some View {
        List {
            ForEach(sessionRows, id: \.id) { session in
                Button {
                    editSessionId = session.id
                } label: {
                    sessionRow(session)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .overlay {
            if sessions.isEmpty {
                emptyState(title: "No workouts yet", description: "Logged workouts will show here. Use + to backdate.")
            }
        }
    }

    private func emptyState(title: String, description: String) -> some View {
        ContentUnavailableView(
            title,
            systemImage: "calendar",
            description: Text(description)
        )
    }

    private struct DayLogEntry: Identifiable {
        var dayKey: String
        var date: Date
        var checkIn: DailyCheckIn?
        var sessions: [TrainingSession]
        var id: String { dayKey }

        var hasPendingWorkout: Bool {
            sessions.contains { !$0.isDraft && $0.response24h == .pending }
        }
    }

    private var dayEntries: [DayLogEntry] {
        var checkByKey: [String: DailyCheckIn] = [:]
        for checkIn in checkIns {
            checkByKey[checkIn.dayKey] = checkIn
        }
        var sessionsByKey: [String: [TrainingSession]] = [:]
        for session in sessions {
            let key = DailyCheckIn.dayKey(for: session.date, calendar: calendar)
            sessionsByKey[key, default: []].append(session)
        }
        let keys = Set(checkByKey.keys).union(sessionsByKey.keys)
        return keys.compactMap { key -> DayLogEntry? in
            let checkIn = checkByKey[key]
            let daySessions = (sessionsByKey[key] ?? []).sorted { $0.createdAt < $1.createdAt }
            let date = checkIn?.date ?? daySessions.first.map { calendar.startOfDay(for: $0.date) }
            guard let date else { return nil }
            return DayLogEntry(dayKey: key, date: date, checkIn: checkIn, sessions: daySessions)
        }
        .sorted { $0.date > $1.date }
    }

    private var sessionRows: [TrainingSession] {
        sessions.sorted { a, b in
            if a.date != b.date { return a.date > b.date }
            return a.createdAt > b.createdAt
        }
    }

    private func daySummaryRow(_ day: DayLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(day.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                Spacer()
                if day.hasPendingWorkout {
                    Text("24h pending")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            metricRow("Morning pain", day.checkIn?.restingPainAM.map(String.init) ?? "—")
            metricRow("Evening pain", day.checkIn?.dailyPainPM.map(String.init) ?? "—")
            metricRow("Steps", day.checkIn?.steps.map { $0.formatted() } ?? "—")
            workoutMetric(day.sessions)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dayAccessibility(day))
    }

    private func sessionRow(_ s: TrainingSession) -> some View {
        let setList = SessionSummary.historyResistanceList(s.resistanceSets())
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Workout")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(AppTheme.quiet)
                    .background(AppTheme.quietFill, in: Capsule())
                    .accessibilityHidden(true)
                sessionTypeTag(s.sessionType)
                if s.isDraft {
                    Text("Draft")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(AppTheme.gold)
                        .background(AppTheme.gold.opacity(0.18), in: Capsule())
                }
                Spacer()
                if !s.isDraft {
                    Text(s.response24h.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(s.response24h == .pending ? .orange : .secondary)
                }
            }
            Text(s.displayTitle)
                .font(.headline)
                .lineLimit(1)
            if let setList {
                HistoryResistanceListView(list: setList)
            }
            metricRow("Date", s.date.formatted(date: .abbreviated, time: .omitted))
            metricRow("Pain during", PainScore.display(s.painDuring))
            metricRow("Pain after", s.displayPainAfter)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(sessionAccessibility(s, setList: setList))
    }

    private func sessionAccessibility(_ s: TrainingSession, setList: HistoryResistanceList?) -> String {
        var parts = [
            "Workout, \(s.displayTitle)",
            s.date.formatted(date: .abbreviated, time: .omitted),
            "Pain during \(PainScore.display(s.painDuring)), after \(s.displayPainAfter)"
        ]
        if s.isDraft {
            parts.append("Draft")
        } else {
            parts.append(s.response24h.title)
        }
        if let setList, !setList.spokenSummary.isEmpty {
            parts.append(setList.spokenSummary)
        }
        return parts.joined(separator: ". ") + "."
    }

    private func workoutMetric(_ daySessions: [TrainingSession]) -> some View {
        let finalized = daySessions.filter { !$0.isDraft }
        let drafts = daySessions.filter(\.isDraft)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("Workout")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(workoutMetricValue(finalized: finalized, drafts: drafts))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(finalized.isEmpty ? Color.secondary : Color.primary)
            }
            if !daySessions.isEmpty {
                Text(daySessions.map(\.displayTitle).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .font(.subheadline)
    }

    private func workoutMetricValue(finalized: [TrainingSession], drafts: [TrainingSession]) -> String {
        if finalized.isEmpty {
            return drafts.isEmpty ? "None" : "Draft"
        }
        if finalized.count == 1 {
            return drafts.isEmpty ? "Yes" : "Yes · draft"
        }
        return drafts.isEmpty ? "Yes · \(finalized.count)" : "Yes · \(finalized.count) · draft"
    }

    private func metricRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .font(.subheadline)
    }

    private func sessionTypeTag(_ type: SessionType) -> some View {
        Text(type.shortTag)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(sessionTypeTagForeground(type))
            .background(sessionTypeTagBackground(type), in: Capsule())
            .accessibilityLabel("Session type: \(type.title)")
    }

    private func sessionTypeTagBackground(_ type: SessionType) -> Color {
        switch type {
        case .isometrics: return Color.blue.opacity(0.22)
        case .hsrStrength: return Color.orange.opacity(0.22)
        case .energyStorage: return Color.purple.opacity(0.22)
        case .tennisSport: return Color.green.opacity(0.22)
        case .other: return Color.secondary.opacity(0.18)
        }
    }

    private func sessionTypeTagForeground(_ type: SessionType) -> Color {
        switch type {
        case .isometrics: return .blue
        case .hsrStrength: return .orange
        case .energyStorage: return .purple
        case .tennisSport: return .green
        case .other: return .secondary
        }
    }

    private func dayAccessibility(_ day: DayLogEntry) -> String {
        let morning = day.checkIn?.restingPainAM.map(String.init) ?? "not logged"
        let evening = day.checkIn?.dailyPainPM.map(String.init) ?? "not logged"
        let steps = day.checkIn?.steps.map { $0.formatted() } ?? "not logged"
        let workout: String
        if day.sessions.isEmpty {
            workout = "no workout"
        } else {
            workout = "workout \(day.sessions.map(\.displayTitle).joined(separator: ", "))"
        }
        return "\(day.date.formatted(date: .abbreviated, time: .omitted)). Morning pain \(morning). Evening pain \(evening). Steps \(steps). \(workout)."
    }
}

/// Layout A: numbered work sets under a quiet count header.
struct HistoryResistanceListView: View {
    let list: HistoryResistanceList

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let header = list.header {
                Text(header)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            ForEach(list.rows) { row in
                if row.isOverflow {
                    Text("+\(list.hiddenWorkCount) more")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(row.spoken)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.kind.label)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(row.isWarmup ? Color.secondary : Color.primary)
                            .frame(width: 28, alignment: .leading)
                        Text(row.dose)
                            .font(.caption.monospacedDigit())
                            .frame(minWidth: 44, alignment: .leading)
                        Text(row.load)
                            .font(.caption.monospacedDigit())
                        Spacer(minLength: 6)
                        if let laterality = row.laterality {
                            Text(laterality)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(row.isWarmup ? Color.secondary : Color.primary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(row.spoken)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HistoryView()
        .environment(AppRouter())
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
