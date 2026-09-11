import SwiftUI
import SwiftData

/// Chronological daily + session feed with backdate + delete (PR-09).
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]

    @State private var filter: Filter = .all
    @State private var editDailyDate: Date?
    @State private var editSessionId: UUID?
    @State private var resolveSessionId: UUID?
    @State private var afterPainSessionId: UUID?
    @State private var showBackdate = false
    @State private var backdateKind: BackdateKind = .daily
    @State private var backdateDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var deleteDailyKey: String?
    @State private var deleteSessionId: UUID?
    @State private var pendingBackdateDaily: Date?
    @State private var pendingBackdateSession: Date?

    private var calendar: Calendar { .current }

    enum Filter: String, CaseIterable, Identifiable, Hashable {
        case all, daily, sessions
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "All"
            case .daily: return "Daily"
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
                .background(Color(.systemBackground))

                TabView(selection: $filter) {
                    allList
                        .tag(Filter.all)
                    dailyList
                        .tag(Filter.daily)
                    workoutsList
                        .tag(Filter.sessions)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Log past check-in") {
                            backdateKind = .daily
                            backdateDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                            showBackdate = true
                        }
                        Button("Log past workout") {
                            backdateKind = .session
                            backdateDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                            showBackdate = true
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
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
                if let id = editSessionId, let s = sessions.first(where: { $0.id == id }) {
                    NavigationStack {
                        SessionEditor(existing: s)
                    }
                    .preferredColorScheme(.dark)
                }
            }
            .sheet(isPresented: Binding(
                get: { resolveSessionId != nil },
                set: { if !$0 { resolveSessionId = nil } }
            )) {
                if let id = resolveSessionId, let s = sessions.first(where: { $0.id == id }) {
                    Resolve24hSheet(session: s)
                }
            }
            .sheet(isPresented: Binding(
                get: { afterPainSessionId != nil },
                set: { if !$0 { afterPainSessionId = nil } }
            )) {
                if let id = afterPainSessionId, let s = sessions.first(where: { $0.id == id }) {
                    AfterPainSheet(session: s)
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
                    .navigationTitle("Log past day")
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
            .confirmationDialog(
                "Delete this workout?",
                isPresented: Binding(
                    get: { deleteSessionId != nil },
                    set: { if !$0 { deleteSessionId = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let id = deleteSessionId,
                       let row = sessions.first(where: { $0.id == id }) {
                        NotificationScheduler.cancelSessionNotifications(sessionId: row.id)
                        modelContext.delete(row)
                        try? modelContext.save()
                        Haptics.warning()
                    }
                    deleteSessionId = nil
                }
                Button("Cancel", role: .cancel) { deleteSessionId = nil }
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
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if dayEntries.isEmpty {
                emptyState(title: "No days yet", description: "Each day will show morning pain, evening pain, steps, and whether you trained. Use + to backdate.")
            }
        }
    }

    private var dailyList: some View {
        List {
            ForEach(checkIns, id: \.dayKey) { checkIn in
                Button {
                    editDailyDate = checkIn.date
                } label: {
                    dailyRow(checkIn)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteDailyKey = checkIn.dayKey
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if checkIns.isEmpty {
                emptyState(title: "No check-ins yet", description: "Morning and evening pain plus steps will show here.")
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
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    if !session.hasLoggedPainAfter {
                        Button {
                            afterPainSessionId = session.id
                        } label: {
                            Label("After", systemImage: "bolt.heart")
                        }
                        .tint(Color.accentColor)
                    }
                    if session.response24h == .pending {
                        Button {
                            resolveSessionId = session.id
                        } label: {
                            Label("Resolve", systemImage: "checkmark.circle")
                        }
                        .tint(.orange)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteSessionId = session.id
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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
            sessions.contains { $0.response24h == .pending }
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

    private func dailyRow(_ c: DailyCheckIn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(c.date.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)
            metricRow("Morning pain", c.restingPainAM.map(String.init) ?? "—")
            metricRow("Evening pain", c.dailyPainPM.map(String.init) ?? "—")
            metricRow("Steps", c.steps.map { $0.formatted() } ?? "—")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(c.date.formatted(date: .abbreviated, time: .omitted)). Morning pain \(c.restingPainAM.map(String.init) ?? "missing"). Evening pain \(c.dailyPainPM.map(String.init) ?? "missing"). Steps \(c.steps.map { $0.formatted() } ?? "missing")."
        )
    }

    private func sessionRow(_ s: TrainingSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Workout")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(Color.accentColor)
                    .background(Color.accentColor.opacity(0.22), in: Capsule())
                    .accessibilityHidden(true)
                sessionTypeTag(s.sessionType)
                Spacer()
                Text(s.response24h.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(s.response24h == .pending ? .orange : .secondary)
            }
            Text(s.displayTitle)
                .font(.headline)
                .lineLimit(1)
            if let resistance = s.resistanceSummary {
                Text(resistance)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            metricRow("Date", s.date.formatted(date: .abbreviated, time: .omitted))
            metricRow("Pain during", String(s.painDuring))
            metricRow("Pain after", s.displayPainAfter)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Workout, \(s.displayTitle). \(s.date.formatted(date: .abbreviated, time: .omitted)). Pain during \(s.painDuring), after \(s.displayPainAfter). \(s.response24h.title)."
        )
    }

    private func workoutMetric(_ daySessions: [TrainingSession]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("Workout")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(daySessions.isEmpty ? "None" : (daySessions.count == 1 ? "Yes" : "Yes · \(daySessions.count)"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(daySessions.isEmpty ? Color.secondary : Color.primary)
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
        let morning = day.checkIn?.restingPainAM.map(String.init) ?? "missing"
        let evening = day.checkIn?.dailyPainPM.map(String.init) ?? "missing"
        let steps = day.checkIn?.steps.map { $0.formatted() } ?? "missing"
        let workout: String
        if day.sessions.isEmpty {
            workout = "no workout"
        } else {
            workout = "workout \(day.sessions.map(\.displayTitle).joined(separator: ", "))"
        }
        return "\(day.date.formatted(date: .abbreviated, time: .omitted)). Morning pain \(morning). Evening pain \(evening). Steps \(steps). \(workout)."
    }
}

#Preview {
    HistoryView()
        .environment(AppRouter())
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
