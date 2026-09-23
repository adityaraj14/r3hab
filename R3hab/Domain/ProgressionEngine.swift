import Foundation

/// One HSR working prescription. Sets are conceptual pairs, not L/R rows.
struct LoadPrescription: Equatable, Sendable {
    var workingSets: Int
    var reps: Int
    var loadLbs: Double?

    var displayLine: String {
        guard let loadLbs else { return "\(workingSets)×\(reps)" }
        return "\(workingSets)×\(reps) @ \(LoadCopy.labeled(loadLbs))"
    }

    var todayLine: String {
        "Today: \(displayLine)"
    }
}

enum ProgressionGate: String, Equatable, CaseIterable, Sendable {
    case consecutiveTopReps
    case painDuring
    case nextMorningBaseline
    case weekOverWeekCreep
}

enum ProgressionStance: String, Equatable, Sendable {
    case hold
    case advance
    case drop
}

struct ProgressionResult: Equatable, Sendable {
    var target: LoadPrescription
    var current: LoadPrescription
    var stance: ProgressionStance
    var blockedBy: [ProgressionGate]
    var laterality: SetLaterality
}

enum SessionPrefill {
    static func workSets(
        from target: LoadPrescription,
        laterality: SetLaterality
    ) -> [ResistanceSet] {
        (0..<target.workingSets).flatMap { _ in
            SessionSummary.makePair(
                reps: target.reps,
                loadLbs: target.loadLbs,
                holdSeconds: nil,
                isWarmup: false
            )
        }
    }

    static func warmupSet(loadLbs: Double?) -> ResistanceSet {
        ResistanceSet(reps: 2, loadLbs: loadLbs, holdSeconds: 30, isWarmup: true)
    }
}

/// Pain-gated double progression in an HSR shell.
///
/// Ladder at a fixed load: 3×8 → 3×10 → 3×12 → 4×8 → 4×10 → 4×12 → +5 lb, 4×8.
/// Today's target is derived from completed primary-load HSR logs. Nothing is stored.
enum ProgressionEngine {
    static let painDuringLimit = 5
    static let loadBumpLbs = 5.0
    static let minLoadLbs = 5.0
    static let defaultSets = 3
    static let defaultReps = 8
    static let weekWindowDays = 7
    static let creepDelta = 1.0
    static let minWeekSamples = 2

    static let pattern: [(sets: Int, reps: Int)] = [
        (3, 8), (3, 10), (3, 12), (4, 8), (4, 10), (4, 12)
    ]

    static func today(
        sessions: [TrainingSessionSnapshot],
        checkIns: [DailyCheckInSnapshot],
        primaryLoadTitle: String = PrimaryLoadCatalog.seatedExtension.title,
        asOf: Date,
        calendar: Calendar = .current
    ) -> ProgressionResult {
        let history = hsrHistory(
            sessions: sessions,
            primaryLoadTitle: primaryLoadTitle,
            calendar: calendar
        )
        let laterality = history.last.map {
            SessionSummary.inferredLaterality(workSets: $0.resistanceSets)
        } ?? .bilateral

        guard let latest = history.last else {
            let seed = LoadPrescription(
                workingSets: defaultSets,
                reps: defaultReps,
                loadLbs: lastPrimaryLoad(
                    sessions: sessions,
                    primaryLoadTitle: primaryLoadTitle
                )
            )
            return ProgressionResult(
                target: seed,
                current: seed,
                stance: .hold,
                blockedBy: [],
                laterality: laterality
            )
        }

        let current = inferPrescription(latest) ?? LoadPrescription(
            workingSets: defaultSets,
            reps: defaultReps,
            loadLbs: latest.chartLoad
        )
        let blocked = blockedGates(
            latest: latest,
            atLevel: sessionsAtLevel(history, prescription: current),
            checkIns: checkIns,
            asOf: asOf,
            calendar: calendar
        )
        let stance = stance(for: blocked, latest: latest, checkIns: checkIns, calendar: calendar)
        let target: LoadPrescription
        switch stance {
        case .advance:
            target = advanced(from: current)
        case .drop:
            target = dropped(from: current)
        case .hold:
            target = current
        }
        return ProgressionResult(
            target: target,
            current: current,
            stance: stance,
            blockedBy: blocked,
            laterality: laterality
        )
    }

    static func evaluateAfterSave(
        sessions: [TrainingSessionSnapshot],
        checkIns: [DailyCheckInSnapshot],
        primaryLoadTitle: String = PrimaryLoadCatalog.seatedExtension.title,
        asOf: Date,
        calendar: Calendar = .current
    ) -> ProgressionResult {
        today(
            sessions: sessions,
            checkIns: checkIns,
            primaryLoadTitle: primaryLoadTitle,
            asOf: asOf,
            calendar: calendar
        )
    }

    static func applySessionPain(_ pain: Int?, to sets: [ResistanceSet]) -> [ResistanceSet] {
        guard let pain, PainScore.isLogged(pain) else { return sets }
        return sets.map { row in
            guard !row.isWarmup, row.painDuring == nil else { return row }
            var copy = row
            copy.painDuring = pain
            return copy
        }
    }

    // MARK: History

    static func hsrHistory(
        sessions: [TrainingSessionSnapshot],
        primaryLoadTitle: String,
        calendar: Calendar
    ) -> [TrainingSessionSnapshot] {
        SessionDraft.finalized(sessions)
            .filter { session in
                session.decision != .rest
                    && session.sessionType == .hsrStrength
                    && matchesPrimaryLoad(session, title: primaryLoadTitle)
                    && !SessionSummary.groupWorkSets(session.resistanceSets.filter { !$0.isWarmup }).isEmpty
            }
            .sorted { a, b in
                let aDay = calendar.startOfDay(for: a.date)
                let bDay = calendar.startOfDay(for: b.date)
                if aDay != bDay { return aDay < bDay }
                return a.createdAt < b.createdAt
            }
    }

    static func matchesPrimaryLoad(_ session: TrainingSessionSnapshot, title: String) -> Bool {
        let head = SessionSummary.displayTitle(whatIDid: session.whatIDid).lowercased()
        let body = session.whatIDid.lowercased()
        return historyNeedles(for: title).contains { needle in
            head.contains(needle) || body.contains(needle)
        }
    }

    /// Current display title, plus the pre-rename short name for seated leg extension.
    /// "Seated extension" stays accepted so historical logs are not orphaned.
    private static func historyNeedles(for title: String) -> [String] {
        let phrases = PrimaryLoadCatalog.all.first {
            $0.title.compare(title, options: .caseInsensitive) == .orderedSame
        }?.historyMatchPhrases ?? [title]
        return phrases.map { $0.lowercased() }
    }

    static func lastPrimaryLoad(
        sessions: [TrainingSessionSnapshot],
        primaryLoadTitle: String
    ) -> Double? {
        SessionDraft.finalized(sessions)
            .filter { matchesPrimaryLoad($0, title: primaryLoadTitle) }
            .sorted { $0.date > $1.date }
            .compactMap(\.chartLoad)
            .first
    }

    // MARK: Infer

    static func inferPrescription(_ session: TrainingSessionSnapshot) -> LoadPrescription? {
        let pairs = SessionSummary.groupWorkSets(session.resistanceSets.filter { !$0.isWarmup })
        guard !pairs.isEmpty else { return nil }
        let minReps = pairs.compactMap(\.reps).min() ?? defaultReps
        let loads = pairs.compactMap(\.leftLoad)
        let load = modalLoad(loads) ?? loads.max()
        let sets: Int
        if pairs.count >= 4 {
            sets = 4
        } else {
            sets = 3
        }
        let reps: Int
        if minReps >= 12 {
            reps = 12
        } else if minReps >= 10 {
            reps = 10
        } else {
            reps = 8
        }
        return LoadPrescription(workingSets: sets, reps: reps, loadLbs: load)
    }

    static func hitTopReps(_ session: TrainingSessionSnapshot, target: LoadPrescription) -> Bool {
        let pairs = SessionSummary.groupWorkSets(session.resistanceSets.filter { !$0.isWarmup })
        guard pairs.count >= target.workingSets else { return false }
        let relevant = Array(pairs.prefix(target.workingSets))
        return relevant.allSatisfy { pair in
            guard let reps = pair.reps, reps >= target.reps else { return false }
            if let need = target.loadLbs {
                let left = pair.leftLoad ?? 0
                let right = pair.rightLoad ?? left
                return left + 0.001 >= need && right + 0.001 >= need
            }
            return true
        }
    }

    static func peakPain(in session: TrainingSessionSnapshot) -> Int? {
        var values: [Int] = []
        if PainScore.isLogged(session.painDuring) {
            values.append(session.painDuring)
        }
        for row in session.resistanceSets where !row.isWarmup {
            if let pain = row.painDuring, PainScore.isLogged(pain) {
                values.append(pain)
            }
        }
        return values.max()
    }

    // MARK: Gates

    static func blockedGates(
        latest: TrainingSessionSnapshot,
        atLevel: [TrainingSessionSnapshot],
        checkIns: [DailyCheckInSnapshot],
        asOf: Date,
        calendar: Calendar
    ) -> [ProgressionGate] {
        guard let current = inferPrescription(latest) else {
            return [.consecutiveTopReps]
        }
        var blocked: [ProgressionGate] = []

        let consecutive = atLevel.suffix(2)
        let twoHits = consecutive.count == 2
            && consecutive.allSatisfy { hitTopReps($0, target: current) }
        if !twoHits {
            blocked.append(.consecutiveTopReps)
        }

        if let pain = peakPain(in: latest), pain > painDuringLimit {
            blocked.append(.painDuring)
        } else if consecutive.count == 2 {
            let anyHigh = consecutive.contains { session in
                guard let pain = peakPain(in: session) else { return false }
                return pain > painDuringLimit
            }
            if anyHigh { blocked.append(.painDuring) }
        }

        let morning = consecutiveMorningVerdict(consecutive, checkIns: checkIns, calendar: calendar)
        switch morning {
        case .fail:
            blocked.append(.nextMorningBaseline)
        case .unknown:
            if twoHits { blocked.append(.nextMorningBaseline) }
        case .pass:
            break
        }

        if weekOverWeekCreep(checkIns: checkIns, asOf: asOf, calendar: calendar) {
            blocked.append(.weekOverWeekCreep)
        }
        return blocked
    }

    private static func stance(
        for blocked: [ProgressionGate],
        latest: TrainingSessionSnapshot,
        checkIns: [DailyCheckInSnapshot],
        calendar: Calendar
    ) -> ProgressionStance {
        if blocked.isEmpty { return .advance }
        if blocked.contains(.weekOverWeekCreep) { return .drop }
        let dropSignals: Set<ProgressionGate> = [.painDuring, .nextMorningBaseline]
        let shouldDrop = blocked.contains { dropSignals.contains($0) }
            && latestDropKnown(latest, checkIns: checkIns, calendar: calendar)
        if shouldDrop { return .drop }
        return .hold
    }

    /// Drop only when a logged signal failed, not when a gate is still unknown.
    private static func latestDropKnown(
        _ latest: TrainingSessionSnapshot,
        checkIns: [DailyCheckInSnapshot],
        calendar: Calendar
    ) -> Bool {
        if let pain = peakPain(in: latest), pain > painDuringLimit { return true }
        if morningVerdict(latest, checkIns: checkIns, calendar: calendar) == .fail { return true }
        return false
    }

    private static func sessionsAtLevel(
        _ history: [TrainingSessionSnapshot],
        prescription: LoadPrescription
    ) -> [TrainingSessionSnapshot] {
        history.filter { inferPrescription($0) == prescription }
    }

    // MARK: Ladder

    static func advanced(from current: LoadPrescription) -> LoadPrescription {
        let index = patternIndex(sets: current.workingSets, reps: current.reps)
        if index < pattern.count - 1 {
            let next = pattern[index + 1]
            return LoadPrescription(
                workingSets: next.sets,
                reps: next.reps,
                loadLbs: current.loadLbs
            )
        }
        let bumped = (current.loadLbs ?? 0) + loadBumpLbs
        return LoadPrescription(workingSets: 4, reps: 8, loadLbs: bumped)
    }

    static func dropped(from current: LoadPrescription) -> LoadPrescription {
        let index = patternIndex(sets: current.workingSets, reps: current.reps)
        if index > 0 {
            let prev = pattern[index - 1]
            return LoadPrescription(
                workingSets: prev.sets,
                reps: prev.reps,
                loadLbs: current.loadLbs
            )
        }
        let reduced = max(minLoadLbs, (current.loadLbs ?? minLoadLbs) - loadBumpLbs)
        return LoadPrescription(workingSets: 3, reps: 8, loadLbs: current.loadLbs == nil ? nil : reduced)
    }

    static func patternIndex(sets: Int, reps: Int) -> Int {
        pattern.firstIndex { $0.sets == sets && $0.reps == reps } ?? 0
    }

    // MARK: Morning / week

    enum MorningVerdict: Equatable {
        case pass
        case fail
        case unknown
    }

    static func morningVerdict(
        _ session: TrainingSessionSnapshot,
        checkIns: [DailyCheckInSnapshot],
        calendar: Calendar
    ) -> MorningVerdict {
        let sessionDay = calendar.startOfDay(for: session.date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: sessionDay) else {
            return .unknown
        }
        guard let nextAM = am(on: nextDay, checkIns: checkIns, calendar: calendar) else {
            return .unknown
        }
        guard let baseline = LoadNudgeEvaluator.baselineMorningPain(
            onOrBefore: sessionDay,
            checkIns: checkIns,
            calendar: calendar
        ) else {
            return .pass
        }
        return nextAM <= baseline ? .pass : .fail
    }

    private static func consecutiveMorningVerdict(
        _ sessions: ArraySlice<TrainingSessionSnapshot>,
        checkIns: [DailyCheckInSnapshot],
        calendar: Calendar
    ) -> MorningVerdict {
        guard sessions.count == 2 else { return .unknown }
        let verdicts = sessions.map { morningVerdict($0, checkIns: checkIns, calendar: calendar) }
        if verdicts.contains(.fail) { return .fail }
        if verdicts.contains(.unknown) { return .unknown }
        return .pass
    }

    static func weekOverWeekCreep(
        checkIns: [DailyCheckInSnapshot],
        asOf: Date,
        calendar: Calendar
    ) -> Bool {
        let today = calendar.startOfDay(for: asOf)
        guard
            let thisStart = calendar.date(byAdding: .day, value: -weekWindowDays, to: today),
            let lastStart = calendar.date(byAdding: .day, value: -weekWindowDays * 2, to: today)
        else {
            return false
        }
        let thisWeek = amScores(checkIns, from: thisStart, to: today, calendar: calendar)
        let lastWeek = amScores(checkIns, from: lastStart, to: thisStart, calendar: calendar)
        guard thisWeek.count >= minWeekSamples, lastWeek.count >= minWeekSamples else {
            return false
        }
        let thisMean = Double(thisWeek.reduce(0, +)) / Double(thisWeek.count)
        let lastMean = Double(lastWeek.reduce(0, +)) / Double(lastWeek.count)
        return thisMean >= lastMean + creepDelta
    }

    private static func amScores(
        _ checkIns: [DailyCheckInSnapshot],
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) -> [Int] {
        checkIns.compactMap { row in
            let day = calendar.startOfDay(for: row.date)
            guard day >= start, day < end else { return nil }
            return row.restingPainAM
        }
    }

    private static func am(
        on day: Date,
        checkIns: [DailyCheckInSnapshot],
        calendar: Calendar
    ) -> Int? {
        let start = calendar.startOfDay(for: day)
        return checkIns.first { calendar.isDate($0.date, inSameDayAs: start) }?.restingPainAM
    }

    private static func modalLoad(_ loads: [Double]) -> Double? {
        guard !loads.isEmpty else { return nil }
        var counts: [Double: Int] = [:]
        for load in loads {
            counts[load, default: 0] += 1
        }
        return counts.max { a, b in
            if a.value != b.value { return a.value < b.value }
            return a.key < b.key
        }?.key
    }
}

private extension TrainingSessionSnapshot {
    var chartLoad: Double? {
        ResistanceMath.chartMaxLoad(work: resistanceSets)
    }
}
