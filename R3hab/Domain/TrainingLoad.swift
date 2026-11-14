import Foundation

/// The three exercises the logger walks through, plus anything already stored
/// that is not one of those three.
enum SessionExerciseKind: String, Equatable, Hashable, Sendable, CaseIterable {
    case isometricLegExtension
    case legExtensionHeavy
    case legPress
    case other

    /// Order on the guided form. `other` is history only.
    static let loggable: [SessionExerciseKind] = [
        .isometricLegExtension,
        .legExtensionHeavy,
        .legPress
    ]

    var title: String {
        switch self {
        case .isometricLegExtension: return "Isometric leg extension holds"
        case .legExtensionHeavy: return "Leg extension heavy sets"
        case .legPress: return "Leg press working sets"
        case .other: return "Session"
        }
    }

    /// Stored in `whatIDid` so new rows match the names already in the diary.
    var storedName: String {
        switch self {
        case .isometricLegExtension: return "Seated leg extension hold"
        case .legExtensionHeavy: return "Seated leg extension"
        case .legPress: return "Leg press"
        case .other: return "Session"
        }
    }

    var sessionType: SessionType {
        switch self {
        case .isometricLegExtension: return .isometrics
        case .legExtensionHeavy, .legPress: return .hsrStrength
        case .other: return .other
        }
    }

    var usesHold: Bool { self == .isometricLegExtension }

    var sortRank: Int {
        switch self {
        case .isometricLegExtension: return 0
        case .legExtensionHeavy: return 1
        case .legPress: return 2
        case .other: return 3
        }
    }
}

/// Training load from stored work sets.
///
/// Working sets: reps × weight (lb). Matched left/right rows are one set, so
/// they count once. Different loads on each leg both count.
/// Isometric holds: holds × seconds × weight (lb·s). A row with a hold uses
/// this, and `reps` is the number of holds (1 when reps is empty).
/// Warm-ups are left out.
struct LoadAmount: Equatable, Sendable {
    var poundReps: Double
    var poundSeconds: Double

    static let zero = LoadAmount(poundReps: 0, poundSeconds: 0)

    var isEmpty: Bool { poundReps <= 0 && poundSeconds <= 0 }
}

enum TrainingLoad {
    static func kind(sessionType: SessionType, whatIDid: String) -> SessionExerciseKind {
        let text = whatIDid.lowercased()
        if text.contains("leg press") || text.contains("single-leg press") {
            return .legPress
        }
        let isExtension = text.contains("leg extension")
            || text.contains("seated extension")
            || text.contains("knee extension")
        let isHold = sessionType == .isometrics || text.contains("hold")
        if isExtension && isHold { return .isometricLegExtension }
        if isExtension { return .legExtensionHeavy }
        return .other
    }

    static func title(kind: SessionExerciseKind, whatIDid: String, sessionType: SessionType) -> String {
        switch kind {
        case .other:
            let name = SessionSummary.displayTitle(whatIDid: whatIDid)
            return name == "Session" ? sessionType.title : name
        case .isometricLegExtension, .legExtensionHeavy, .legPress:
            return kind.title
        }
    }

    static func amount(for sets: [ResistanceSet]) -> LoadAmount {
        let pairs = SessionSummary.groupWorkSets(sets.filter { !$0.isWarmup })
        var total = LoadAmount.zero
        for pair in pairs {
            let reps = Double(pair.reps ?? 0)
            let hold = pair.holdSeconds ?? 0
            for load in loads(in: pair) where load > 0 {
                if hold > 0 {
                    let holds = reps > 0 ? reps : 1
                    total.poundSeconds += holds * Double(hold) * load
                } else if reps > 0 {
                    total.poundReps += reps * load
                }
            }
        }
        return total
    }

    /// Same load on both knees is one machine set. Different loads both count.
    private static func loads(in pair: WorkSetPair) -> [Double] {
        if pair.right == nil {
            return pair.leftLoad.map { [$0] } ?? []
        }
        if pair.loadsMatch {
            return pair.leftLoad.map { [$0] } ?? pair.rightLoad.map { [$0] } ?? []
        }
        return [pair.leftLoad, pair.rightLoad].compactMap { $0 }
    }

    static func formatted(_ value: Double) -> String {
        let number = NSNumber(value: value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.rounded() == value ? 0 : 1
        formatter.minimumFractionDigits = 0
        return formatter.string(from: number) ?? String(format: "%g", value)
    }

    static func poundRepsText(_ value: Double) -> String {
        "\(formatted(value)) lb"
    }

    static func poundSecondsText(_ value: Double) -> String {
        "\(formatted(value)) lb·s"
    }

    /// One line for a day that may mix working sets and holds.
    static func summary(poundReps: Double, poundSeconds: Double) -> String? {
        var parts: [String] = []
        if poundReps > 0 { parts.append(poundRepsText(poundReps)) }
        if poundSeconds > 0 { parts.append(poundSecondsText(poundSeconds)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// One exercise on the guided form, before it is saved.
struct ExerciseEntryDraft: Equatable, Sendable, Identifiable {
    var kind: SessionExerciseKind
    var included: Bool
    var loadLbs: Double
    var sets: Int
    var reps: Int
    var holdSeconds: Int
    var pain: Int?

    var id: SessionExerciseKind { kind }
}

enum ExerciseEntry {
    static let defaultIsoHolds = 5
    static let defaultHoldSeconds = 45
    static let defaultSets = 4
    static let defaultReps = 8
    static let loadStep = 5.0
    static let maxLoad = 600.0
    static let maxCount = 12
    static let maxReps = 30
    static let maxHoldSeconds = 120

    static func make(kind: SessionExerciseKind, from sessions: [TrainingSessionSnapshot]) -> ExerciseEntryDraft {
        let previous = sessions
            .filter { $0.isFinalized && TrainingLoad.kind(sessionType: $0.sessionType, whatIDid: $0.whatIDid) == kind }
            .max { $0.date == $1.date ? $0.createdAt < $1.createdAt : $0.date < $1.date }
        let pairs = SessionSummary.groupWorkSets((previous?.resistanceSets ?? []).filter { !$0.isWarmup })
        let first = pairs.first
        let load = first?.leftLoad ?? first?.rightLoad ?? 0
        if kind.usesHold {
            let holds: Int
            if pairs.count <= 1, let reps = first?.reps, reps > 0 {
                holds = reps
            } else if !pairs.isEmpty {
                holds = pairs.count
            } else {
                holds = defaultIsoHolds
            }
            return ExerciseEntryDraft(
                kind: kind,
                included: true,
                loadLbs: max(load, 0),
                sets: min(max(holds, 1), maxCount),
                reps: defaultReps,
                holdSeconds: min(max(first?.holdSeconds ?? defaultHoldSeconds, 1), maxHoldSeconds),
                pain: nil
            )
        }
        let setCount = pairs.isEmpty ? defaultSets : pairs.count
        return ExerciseEntryDraft(
            kind: kind,
            included: true,
            loadLbs: max(load, 0),
            sets: min(max(setCount, 1), maxCount),
            reps: min(max(first?.reps ?? defaultReps, 1), maxReps),
            holdSeconds: defaultHoldSeconds,
            pain: nil
        )
    }

    /// Nil when this exercise can be saved, or when it was skipped.
    static func issue(for draft: ExerciseEntryDraft) -> String? {
        guard draft.included else { return nil }
        if draft.loadLbs <= 0 { return "Enter a weight above 0, or skip this exercise." }
        if draft.kind.usesHold {
            if draft.sets <= 0 { return "Enter how many holds you did." }
            if draft.holdSeconds <= 0 { return "Enter the hold time in seconds." }
        } else {
            if draft.sets <= 0 { return "Enter how many sets you did." }
            if draft.reps <= 0 { return "Enter the reps in each set." }
        }
        guard let pain = draft.pain, PainScore.isLogged(pain) else {
            return "Record pain during this exercise, from 0 to 10."
        }
        return nil
    }

    static func resistanceSets(for draft: ExerciseEntryDraft) -> [ResistanceSet] {
        if draft.kind.usesHold {
            return [
                ResistanceSet(
                    reps: draft.sets,
                    loadLbs: draft.loadLbs,
                    holdSeconds: draft.holdSeconds,
                    isWarmup: false
                )
            ]
        }
        return (0..<max(draft.sets, 0)).map { _ in
            ResistanceSet(reps: draft.reps, loadLbs: draft.loadLbs, holdSeconds: nil, isWarmup: false)
        }
    }

    static func doseLine(for draft: ExerciseEntryDraft) -> String? {
        SessionSummary.compactResistance(resistanceSets(for: draft))
    }
}

struct NewSessionLog: Equatable, Sendable {
    var kind: SessionExerciseKind
    var sessionType: SessionType
    var whatIDid: String
    var painDuring: Int
    var sets: [ResistanceSet]
}

enum GuidedSessionDraft: Equatable, Sendable {
    static func exercises(from sessions: [TrainingSessionSnapshot]) -> [ExerciseEntryDraft] {
        SessionExerciseKind.loggable.map { ExerciseEntry.make(kind: $0, from: sessions) }
    }

    /// Included exercises that pass validation, in form order.
    static func logs(from exercises: [ExerciseEntryDraft]) -> [NewSessionLog] {
        exercises.compactMap { draft in
            guard draft.included, ExerciseEntry.issue(for: draft) == nil, let pain = draft.pain else {
                return nil
            }
            return NewSessionLog(
                kind: draft.kind,
                sessionType: draft.kind.sessionType,
                whatIDid: draft.kind.storedName,
                painDuring: pain,
                sets: ExerciseEntry.resistanceSets(for: draft)
            )
        }
    }
}

struct SessionLogEntry: Equatable, Identifiable, Sendable {
    var id: UUID
    var createdAt: Date
    var title: String
    var kind: SessionExerciseKind
    var dose: String?
    var pain: String
    var poundReps: Double
    var poundSeconds: Double
}

struct SessionLogDay: Equatable, Identifiable, Sendable {
    var day: Date
    var entries: [SessionLogEntry]

    var id: Date { day }

    var poundReps: Double { entries.reduce(0) { $0 + $1.poundReps } }
    var poundSeconds: Double { entries.reduce(0) { $0 + $1.poundSeconds } }
}

struct LoadTrendPoint: Equatable, Identifiable, Sendable {
    var day: Date
    var value: Double

    var id: Date { day }
}

enum SessionLogBuilder {
    static let trendLimit = 8

    static let formulaNote = """
    Working-set load is reps × weight, in lb. Isometric load is holds × seconds × weight, in lb·s. Warm-ups are left out. A left and right row with the same weight counts once.
    """

    static func days(
        from sessions: [TrainingSessionSnapshot],
        calendar: Calendar = .current
    ) -> [SessionLogDay] {
        let complete = sessions.filter(\.isFinalized)
        let grouped = Dictionary(grouping: complete) { calendar.startOfDay(for: $0.date) }
        let days = grouped.map { day, rows -> SessionLogDay in
            let entries = rows
                .map { entry(from: $0) }
                .sorted { lhs, rhs in
                    if lhs.kind.sortRank != rhs.kind.sortRank { return lhs.kind.sortRank < rhs.kind.sortRank }
                    return lhs.createdAt < rhs.createdAt
                }
            return SessionLogDay(day: day, entries: entries)
        }
        return days.sorted { $0.day > $1.day }
    }

    static func entry(from session: TrainingSessionSnapshot) -> SessionLogEntry {
        let kind = TrainingLoad.kind(sessionType: session.sessionType, whatIDid: session.whatIDid)
        let amount = TrainingLoad.amount(for: session.resistanceSets)
        return SessionLogEntry(
            id: session.id,
            createdAt: session.createdAt,
            title: TrainingLoad.title(kind: kind, whatIDid: session.whatIDid, sessionType: session.sessionType),
            kind: kind,
            dose: SessionSummary.compactResistance(session.resistanceSets),
            pain: PainScore.isLogged(session.painDuring) ? "Pain \(session.painDuring)" : "",
            poundReps: amount.poundReps,
            poundSeconds: amount.poundSeconds
        )
    }

    static func workingSetTrend(from days: [SessionLogDay], limit: Int = trendLimit) -> [LoadTrendPoint] {
        trend(from: days, limit: limit) { $0.poundReps }
    }

    static func isometricTrend(from days: [SessionLogDay], limit: Int = trendLimit) -> [LoadTrendPoint] {
        trend(from: days, limit: limit) { $0.poundSeconds }
    }

    private static func trend(
        from days: [SessionLogDay],
        limit: Int,
        value: (SessionLogDay) -> Double
    ) -> [LoadTrendPoint] {
        let points = days
            .map { LoadTrendPoint(day: $0.day, value: value($0)) }
            .filter { $0.value > 0 }
            .sorted { $0.day < $1.day }
        if points.count <= limit { return points }
        return Array(points.suffix(limit))
    }
}
