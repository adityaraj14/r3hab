import SwiftUI
import SwiftData

/// Chronological daily + session feed.
struct HistoryView: View {
    @Query(sort: \DailyCheckIn.date, order: .reverse) private var checkIns: [DailyCheckIn]
    @Query(sort: \TrainingSession.date, order: .reverse) private var sessions: [TrainingSession]

    @State private var filter: Filter = .all
    @State private var editDailyKey: String?
    @State private var resolveSessionId: UUID?

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
                    case .session(let s):
                        Button {
                            if s.response24h == .pending {
                                resolveSessionId = s.id
                            }
                        } label: {
                            sessionRow(s)
                        }
                    }
                }
            }
            .navigationTitle("Log")
            .overlay {
                if rows.isEmpty {
                    ContentUnavailableView(
                        "No entries yet",
                        systemImage: "calendar",
                        description: Text("Check-ins and sessions will show here.")
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
                get: { resolveSessionId != nil },
                set: { if !$0 { resolveSessionId = nil } }
            )) {
                if let id = resolveSessionId, let s = sessions.first(where: { $0.id == id }) {
                    Resolve24hSheet(session: s)
                }
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
            case .session(let s): return s.date
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
            Text("AM \(c.restingPainAM.map(String.init) ?? "—") · PM \(c.dailyPainPM.map(String.init) ?? "—") · steps \(c.steps.map(String.init) ?? "—")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func sessionRow(_ s: TrainingSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(s.whatIDid)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Text(s.response24h.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(s.response24h == .pending ? .orange : .secondary)
            }
            Text("\(s.date.formatted(date: .abbreviated, time: .omitted)) · \(s.painDuring)/\(s.painAfter)\(s.decision.map { " · \($0.title)" } ?? "")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// sheet(item:) uses dayKey via explicit Binding helpers when needed

#Preview {
    HistoryView()
        .modelContainer(for: [DailyCheckIn.self, TrainingSession.self, AppSettings.self], inMemory: true)
        .preferredColorScheme(.dark)
}
