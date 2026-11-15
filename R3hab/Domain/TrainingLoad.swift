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

    /// One line per hold or working set, in stored order.
    ///
    /// An older isometric row keeps several identical holds on one
    /// `ResistanceSet`, with `reps` as the hold count. Those expand into one
    /// line per hold. The stored row is not rewritten. Warm-ups are left out.
    /// A matched left/right pair is one line. Different loads name both legs.
    static func lines(for sets: [ResistanceSet]) -> [SetLoadLine] {
        let pairs = SessionSummary.groupWorkSets(sets.filter { !$0.isWarmup })
        var lines: [SetLoadLine] = []
        for pair in pairs {
            let pairLoads = loads(in: pair).filter { $0 > 0 }
            guard !pairLoads.isEmpty else { continue }
            let hold = pair.holdSeconds ?? 0
            let reps = pair.reps ?? 0
            if hold > 0 {
                let count = reps > 0 ? reps : 1
                let text = doseText(effort: "\(hold)s", loads: pairLoads, pair: pair)
                let each = pairLoads.reduce(0.0) { $0 + (Double(hold) * $1) }
                for _ in 0..<count {
                    lines.append(
                        SetLoadLine(index: lines.count, text: text, poundReps: 0, poundSeconds: each)
                    )
                }
            } else if reps > 0 {
                let text = doseText(effort: "\(reps) reps", loads: pairLoads, pair: pair)
                let total = pairLoads.reduce(0.0) { $0 + (Double(reps) * $1) }
                lines.append(
                    SetLoadLine(index: lines.count, text: text, poundReps: total, poundSeconds: 0)
                )
            }
        }
        return lines
    }

    /// Reference text for the guided form. One line per stored set. An older
    /// isometric row with several identical holds stays one aggregate line.
    static func comparisonLines(for sets: [ResistanceSet]) -> [String] {
        let pairs = SessionSummary.groupWorkSets(sets.filter { !$0.isWarmup })
        var lines: [String] = []
        for pair in pairs {
            let pairLoads = loads(in: pair).filter { $0 > 0 }
            let hold = pair.holdSeconds ?? 0
            let reps = pair.reps ?? 0
            let effort: String
            if hold > 0 {
                effort = reps > 1 ? "\(reps) × \(hold)s" : "\(hold)s"
            } else if reps > 0 {
                effort = "\(reps) reps"
            } else {
                continue
            }
            if pairLoads.isEmpty {
                lines.append(effort)
            } else {
                lines.append(doseText(effort: effort, loads: pairLoads, pair: pair))
            }
        }
        return compactIdentical(lines)
    }

    /// "45s, 45s, 45s" becomes "3 × 45s" so a last-session card stays short.
    private static func compactIdentical(_ lines: [String]) -> [String] {
        var compacted: [String] = []
        var index = 0
        while index < lines.count {
            var end = index + 1
            while end < lines.count, lines[end] == lines[index] {
                end += 1
            }
            let count = end - index
            compacted.append(count > 1 ? "\(count) × \(lines[index])" : lines[index])
            index = end
        }
        return compacted
    }

    private static func doseText(effort: String, loads: [Double], pair: WorkSetPair) -> String {
        if loads.count >= 2, !pair.loadsMatch {
            let left = LoadCopy.formatted(loads[0])
            let right = LoadCopy.formatted(loads[1])
            return "\(effort) @ \(left) lb left, \(right) lb right"
        }
        let weight = LoadCopy.formatted(loads[0])
        if pair.right == nil, let side = pair.left.side {
            return "\(effort) @ \(weight) lb \(side.title.lowercased())"
        }
        return "\(effort) @ \(weight) lb"
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

/// One set on the guided form. Weight is its own. Holds use seconds; working sets use reps.
struct LoggedSetDraft: Equatable, Sendable, Identifiable {
    var id: UUID
    var loadLbs: Double
    var reps: Int
    var holdSeconds: Int

    init(id: UUID = UUID(), loadLbs: Double, reps: Int, holdSeconds: Int) {
        self.id = id
        self.loadLbs = loadLbs
        self.reps = reps
        self.holdSeconds = holdSeconds
    }
}

/// One line in the log for a single hold or working set.
struct SetLoadLine: Equatable, Sendable, Identifiable {
    var index: Int
    var text: String
    var poundReps: Double
    var poundSeconds: Double

    var id: Int { index }
}

/// One exercise on the guided form, before it is saved.
struct ExerciseEntryDraft: Equatable, Sendable, Identifiable {
    var kind: SessionExerciseKind
    var included: Bool
    var sets: [LoggedSetDraft]
    var pain: Int?

    var id: SessionExerciseKind { kind }
}

enum ExerciseEntry {
    static let defaultHoldSeconds = 45
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
        return ExerciseEntryDraft(
            kind: kind,
            included: true,
            sets: loggedSets(kind: kind, from: pairs),
            pain: nil
        )
    }

    /// Turns stored work into editable sets.
    ///
    /// A single isometric row with `reps` greater than 1 is several identical
    /// holds (the aggregate logger, including the Nov 12 and 13 rows). Each
    /// hold becomes its own set. Rows that are already one hold or one working
    /// set stay one set. Matched left/right pairs stay one set.
    static func loggedSets(kind: SessionExerciseKind, from pairs: [WorkSetPair]) -> [LoggedSetDraft] {
        var sets: [LoggedSetDraft] = []
        for pair in pairs {
            if sets.count >= maxCount { break }
            let load = max(pair.leftLoad ?? pair.rightLoad ?? 0, 0)
            if kind.usesHold {
                guard let seconds = pair.holdSeconds, seconds > 0 else { continue }
                let clamped = min(max(seconds, 1), maxHoldSeconds)
                let count = min(max(pair.reps ?? 1, 1), maxCount - sets.count)
                for _ in 0..<count {
                    sets.append(
                        LoggedSetDraft(loadLbs: load, reps: defaultReps, holdSeconds: clamped)
                    )
                }
            } else {
                sets.append(
                    LoggedSetDraft(
                        loadLbs: load,
                        reps: min(max(pair.reps ?? defaultReps, 1), maxReps),
                        holdSeconds: defaultHoldSeconds
                    )
                )
            }
        }
        if sets.isEmpty {
            sets = [blankSet(kind: kind)]
        }
        return sets
    }

    static func blankSet(kind: SessionExerciseKind, weight: Double = 0) -> LoggedSetDraft {
        LoggedSetDraft(
            loadLbs: min(max(weight, 0), maxLoad),
            reps: defaultReps,
            holdSeconds: defaultHoldSeconds
        )
    }

    /// A new set at the last weight, with the usual reps or seconds.
    static func addSet(to draft: inout ExerciseEntryDraft) {
        guard draft.sets.count < maxCount else { return }
        draft.sets.append(blankSet(kind: draft.kind, weight: draft.sets.last?.loadLbs ?? 0))
    }

    /// Copies the last set so a repeated hold or working set does not need retyping.
    static func duplicateLastSet(in draft: inout ExerciseEntryDraft) {
        guard draft.sets.count < maxCount, let last = draft.sets.last else { return }
        draft.sets.append(
            LoggedSetDraft(loadLbs: last.loadLbs, reps: last.reps, holdSeconds: last.holdSeconds)
        )
    }

    static func removeSet(_ id: UUID, from draft: inout ExerciseEntryDraft) {
        draft.sets.removeAll { $0.id == id }
    }

    /// Nil when this exercise can be saved, or when it was skipped.
    static func issue(for draft: ExerciseEntryDraft) -> String? {
        guard draft.included else { return nil }
        if draft.sets.isEmpty { return "Add a set, or skip this exercise." }
        if draft.sets.contains(where: { $0.loadLbs <= 0 }) {
            return "Enter a weight above 0 on every set, or skip this exercise."
        }
        if draft.kind.usesHold {
            if draft.sets.contains(where: { $0.holdSeconds <= 0 }) {
                return "Enter the seconds for every hold."
            }
        } else if draft.sets.contains(where: { $0.reps <= 0 }) {
            return "Enter the reps for every set."
        }
        guard let pain = draft.pain, PainScore.isLogged(pain) else {
            return "Record pain during this exercise, from 0 to 10."
        }
        return nil
    }

    static func resistanceSets(for draft: ExerciseEntryDraft) -> [ResistanceSet] {
        draft.sets.map { set in
            if draft.kind.usesHold {
                return ResistanceSet(
                    reps: 1,
                    loadLbs: set.loadLbs,
                    holdSeconds: set.holdSeconds,
                    isWarmup: false
                )
            }
            return ResistanceSet(reps: set.reps, loadLbs: set.loadLbs, holdSeconds: nil, isWarmup: false)
        }
    }
}

struct NewSessionLog: Equatable, Sendable {
    var kind: SessionExerciseKind
    var sessionType: SessionType
    var whatIDid: String
    var painDuring: Int
    var sets: [ResistanceSet]
}

/// The latest saved session for one exercise, shown beside the form.
struct PriorExercise: Equatable, Sendable {
    var day: Date
    var lines: [String]
    var sets: [LoggedSetDraft]
}

enum PriorExerciseLookup {
    static func latest(
        kind: SessionExerciseKind,
        in sessions: [TrainingSessionSnapshot],
        calendar: Calendar = .current
    ) -> PriorExercise? {
        let match = sessions
            .filter { $0.isFinalized && TrainingLoad.kind(sessionType: $0.sessionType, whatIDid: $0.whatIDid) == kind }
            .max { $0.date == $1.date ? $0.createdAt < $1.createdAt : $0.date < $1.date }
        guard let match else { return nil }
        let lines = TrainingLoad.comparisonLines(for: match.resistanceSets)
        guard !lines.isEmpty else { return nil }
        let pairs = SessionSummary.groupWorkSets(match.resistanceSets.filter { !$0.isWarmup })
        return PriorExercise(
            day: calendar.startOfDay(for: match.date),
            lines: lines,
            sets: ExerciseEntry.loggedSets(kind: kind, from: pairs)
        )
    }

    static func dateLabel(day: Date, now: Date, calendar: Calendar = .current) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        let month = calendar.component(.month, from: day)
        let dayNumber = calendar.component(.day, from: day)
        let name = calendar.shortMonthSymbols[month - 1]
        return "\(name) \(dayNumber)"
    }
}

/// What Home shows for today's step count. The HealthKit read lives in the app target.
enum TodayStepsState: Equatable, Sendable {
    case notAsked
    case count(Int)
    case unavailable
}

enum TodayStepsCopy {
    static func label(_ state: TodayStepsState) -> String {
        switch state {
        case .notAsked:
            return "Steps from Apple Health"
        case .count(let steps):
            return "\(formatted(max(steps, 0))) steps today"
        case .unavailable:
            return "Steps unavailable"
        }
    }

    static func formatted(_ steps: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: max(steps, 0))) ?? String(max(steps, 0))
    }
}

enum GuidedSessionDraft: Equatable, Sendable {
    /// The day a guided log is saved under. A future pick becomes today.
    /// Rows keep the start of the day, the same as every other saved session.
    static func sessionDay(chosen: Date, now: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: min(chosen, now))
    }

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
    /// One line per hold or working set. Empty when the row has no load to split.
    var setLines: [String] = []
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
    Working-set load adds reps × weight for each set, in lb. Isometric load adds seconds × weight for each hold, in lb·s. An older entry that stored several identical holds still counts each hold. Warm-ups are left out. A left and right row with the same weight counts once.
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
        let lines = TrainingLoad.lines(for: session.resistanceSets)
        return SessionLogEntry(
            id: session.id,
            createdAt: session.createdAt,
            title: TrainingLoad.title(kind: kind, whatIDid: session.whatIDid, sessionType: session.sessionType),
            kind: kind,
            dose: lines.isEmpty ? SessionSummary.compactResistance(session.resistanceSets) : nil,
            setLines: lines.map(\.text),
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
