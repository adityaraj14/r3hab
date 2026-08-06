import SwiftUI
import SwiftData

/// Chronological daily + session feed with backdate + delete (PR-09).
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]

    @State private var filter: Filter = .all
    @State private var editDailyKey: String?
    @State private var editSessionId: UUID?
    @State private var resolveSessionId: UUID?
    @State private var showBackdate = false
    @State private var backdateKind: BackdateKind = .daily
    @State private var backdateDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var deleteDailyKey: String?
    @State private var deleteSessionId: UUID?
    @State private var pendingBackdateDaily: Date?
    @State private var pendingBackdateSession: Date?

    enum Filter: String, CaseIterable, Identifiable {
        case all, daily, sessions
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "All"
            case .daily: return "Daily"
            case .sessions: return "Sessions"
            }
        }
    }

    enum BackdateKind: String, CaseIterable, Identifiable {
        case daily, session, hipThrust
        var id: String { rawValue }
        var title: String {
            switch self {
            case .daily: return "Check-in"
            case .session: return "Knee session"
            case .hipThrust: return "Hip thrust"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { f in
                        Text(f.title).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                ForEach(rows, id: \.id) { row in
                    switch row {
                    case .daily(let c):
                        Button {
                            editDailyKey = c.dayKey
                        } label: {
                            dailyRow(c)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteDailyKey = c.dayKey
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    case .session(let s):
                        Button {
                            editSessionId = s.id
                        } label: {
                            sessionRow(s)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if s.response24h == .pending {
                                Button {
                                    resolveSessionId = s.id
                                } label: {
                                    Label("Resolve", systemImage: "checkmark.circle")
                                }
                                .tint(.orange)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteSessionId = s.id
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
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
                        Button("Log past knee session") {
                            backdateKind = .session
                            backdateDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                            showBackdate = true
                        }
                        Button("Log past hip thrust") {
                            backdateKind = .hipThrust
                            backdateDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                            showBackdate = true
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            .overlay {
                if rows.isEmpty {
                    ContentUnavailableView(
                        "No entries yet",
                        systemImage: "calendar",
                        description: Text("Check-ins and sessions will show here. Use + to backdate.")
                    )
                }
            }
            .sheet(isPresented: Binding(
                get: { editDailyKey != nil },
                set: { if !$0 { editDailyKey = nil } }
            )) {
                if let key = editDailyKey, let c = checkIns.first(where: { $0.dayKey == key }) {
                    NavigationStack {
                        DailyCheckInEditor(targetDate: c.date)
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
                                        editDailyKey = DailyCheckIn.dayKey(for: backdateDate)
                                        pendingBackdateDaily = Calendar.current.startOfDay(for: backdateDate)
                                    case .session, .hipThrust:
                                        pendingBackdateSession = Calendar.current.startOfDay(for: backdateDate)
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
                            focus: backdateKind == .hipThrust ? .lowerBackResistance : .kneeResistance
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
                "Delete this session?",
                isPresented: Binding(
                    get: { deleteSessionId != nil },
                    set: { if !$0 { deleteSessionId = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let id = deleteSessionId,
                       let row = sessions.first(where: { $0.id == id }) {
                        NotificationScheduler.cancelPending(sessionId: row.id)
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

    private enum Row {
        case daily(DailyCheckIn)
        case session(TrainingSession)
        var id: String {
            switch self {
            case .daily(let c): return "d-\(c.dayKey)"
            case .session(let s): return "s-\(s.id.uuidString)"
            }
        }
        var sortDate: Date {
            switch self {
            case .daily(let c): return c.date
            case .session(let s): return max(s.date, s.createdAt)
            }
        }
    }

    private var rows: [Row] {
        var items: [Row] = []
        if filter != .sessions {
            items += checkIns.map { .daily($0) }
        }
        if filter != .daily {
            items += sessions.map { .session($0) }
        }
        return items.sorted { $0.sortDate > $1.sortDate }
    }

    private func dailyRow(_ c: DailyCheckIn) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(c.date.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)
            Text(dailySummary(c))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func dailySummary(_ c: DailyCheckIn) -> String {
        let kneeAM = c.restingPainAM.map(String.init) ?? "—"
        let kneePM = c.dailyPainPM.map(String.init) ?? "—"
        let backAM = c.lowerBackPainAM.map(String.init) ?? "—"
        let backPM = c.lowerBackPainPM.map(String.init) ?? "—"
        let steps = c.steps.map(String.init) ?? "—"
        return "Knee \(kneeAM)/\(kneePM) · Back \(backAM)/\(backPM) · steps \(steps)"
    }

    private func sessionRow(_ s: TrainingSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(s.whatIDid)
                    .font(.headline)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(s.response24h.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(s.response24h == .pending ? .orange : .secondary)
            }
            HStack(spacing: 6) {
                sessionTypeTag(s.sessionType)
                if let region = s.effectiveLoadRegion, s.hasResistanceLog {
                    regionTag(region)
                }
            }
            Text(sessionSubtitle(s))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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

    private func regionTag(_ region: LoadRegion) -> some View {
        Text(region == .lowerBack ? "Back" : "Knee")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(.secondary)
            .background(Color(.tertiarySystemFill), in: Capsule())
    }

    private func sessionSubtitle(_ s: TrainingSession) -> String {
        var parts = [
            s.date.formatted(date: .abbreviated, time: .omitted),
            "\(s.painDuring)/\(s.painAfter)"
        ]
        if let resistance = s.resistanceSummary {
            parts.append(resistance)
        }
        if let decision = s.decision {
            parts.append(decision.title)
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
