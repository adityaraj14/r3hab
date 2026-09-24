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

    /// Last logged dose. Not a computed next load.
    var lastTimeLine: String {
        "Last time: \(displayLine)"
    }
}

enum ProgressionGate: String, Equatable, CaseIterable, Sendable {
    case painDuring
    case awaiting24h
    case responseWorse
    case consecutiveCleanHits
}

enum ProgressionStance: String, Equatable, Sendable {
    case hold
    case advance
    case drop

    /// Advice only. The form still opens on last session’s weight.
    var label: String {
        switch self {
        case .hold: return "Hold load"
        case .advance: return "Increase load"
        case .drop: return "Decrease load"
        }
    }
}

struct ProgressionResult: Equatable, Sendable {
    var target: LoadPrescription
    var current: LoadPrescription
    var stance: ProgressionStance
    /// One line for the gold card. Never empty.
    var reason: String
    var blockedBy: [ProgressionGate]
    var laterality: SetLaterality
    /// Set when the latest primary-load session still needs a 24h resolve.
    var pendingResolveID: UUID?
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

/// Option B gates. Stance is advice. Prefill weight is the last working load.
/// Set and rep shape snaps into 3×8–12. The engine does not write +5 or −5.
enum ProgressionEngine {
    static let painDuringLimit = 3
    static let defaultSets = 3
    static let defaultReps = 8
    static let repFloor = 8
    static let repCeiling = 12
    static let repHardMax = 15

    static let reasonWaitingOn24h = "Waiting on 24h check-in"
    static let reasonWorseHolding = "24h Worse — holding load"
    static let reasonTwoCleanIncrease = "Two clean hits — increase load"
    static let reasonOneClean = "One clean hit — holding load"
    static let reasonShortReps = "Reps were short — holding load"
    static let reasonStart = "Start at 3×8"
    static let reasonNotApplicable = "24h not applicable — holding load"
    static let reasonPainUnlogged = "Pain during was not logged"
    static let reasonHolding = "Holding load"

    static func reasonPain(_ pain: Int) -> String {
        "Pain during was \(pain)"
    }

    static func today(
        sessions: [TrainingSessionSnapshot],
        primaryLoadTitle: String = PrimaryLoadCatalog.seatedExtension.title,
        asOf: Date,
        calendar: Calendar = .current
    ) -> ProgressionResult {
        let asOfDay = calendar.startOfDay(for: asOf)
        let history = hsrHistory(
            sessions: sessions,
            primaryLoadTitle: primaryLoadTitle,
            calendar: calendar
        ).filter { calendar.startOfDay(for: $0.date) <= asOfDay }

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
                reason: reasonStart,
                blockedBy: [],
                laterality: laterality,
                pendingResolveID: nil
            )
        }

        let raw = inferPrescription(latest) ?? LoadPrescription(
            workingSets: defaultSets,
            reps: defaultReps,
            loadLbs: latest.chartLoad
        )
        let current = snap(raw)
        let pendingID: UUID? = latest.response24h == .pending ? latest.id : nil
        let pain = peakPain(in: latest)

        if let pain, pain > painDuringLimit {
            return make(
                target: current,
                current: current,
                stance: .drop,
                reason: reasonPain(pain),
                blockedBy: [.painDuring],
                laterality: laterality,
                pendingResolveID: pendingID
            )
        }

        switch latest.response24h {
        case .pending:
            return make(
                target: current,
                current: current,
                stance: .hold,
                reason: reasonWaitingOn24h,
                blockedBy: [.awaiting24h],
                laterality: laterality,
                pendingResolveID: pendingID
            )
        case .worse:
            return make(
                target: current,
                current: current,
                stance: .hold,
                reason: reasonWorseHolding,
                blockedBy: [.responseWorse],
                laterality: laterality,
                pendingResolveID: nil
            )
        case .notApplicable:
            return make(
                target: current,
                current: current,
                stance: .hold,
                reason: reasonNotApplicable,
                blockedBy: [.awaiting24h],
                laterality: laterality,
                pendingResolveID: nil
            )
        case .better, .same:
            break
        }

        let atLoad = sessionsAtLoad(history, loadLbs: current.loadLbs)
        let recent = Array(atLoad.suffix(2))
        let twoClean = recent.count == 2 && recent.allSatisfy {
            isCleanHit($0, loadLbs: current.loadLbs)
        }
        if twoClean {
            return make(
                target: current,
                current: current,
                stance: .advance,
                reason: reasonTwoCleanIncrease,
                blockedBy: [],
                laterality: laterality,
                pendingResolveID: nil
            )
        }

        return make(
            target: current,
            current: current,
            stance: .hold,
            reason: holdReason(latest: latest, loadLbs: current.loadLbs),
            blockedBy: [.consecutiveCleanHits],
            laterality: laterality,
            pendingResolveID: nil
        )
    }

    static func evaluateAfterSave(
        sessions: [TrainingSessionSnapshot],
        primaryLoadTitle: String = PrimaryLoadCatalog.seatedExtension.title,
        asOf: Date,
        calendar: Calendar = .current
    ) -> ProgressionResult {
        today(
            sessions: sessions,
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
        return LoadPrescription(workingSets: pairs.count, reps: minReps, loadLbs: load)
    }

    /// Keep the logged load. Collapse set-count climbs into 3 sets.
    /// Reps land in 8–12. Anything above the hard max (15) is pulled back too.
    static func snap(_ raw: LoadPrescription) -> LoadPrescription {
        let capped = min(raw.reps, repHardMax)
        let reps: Int
        if capped < repFloor {
            reps = repFloor
        } else if capped > repCeiling {
            reps = repCeiling
        } else {
            reps = capped
        }
        return LoadPrescription(workingSets: defaultSets, reps: reps, loadLbs: raw.loadLbs)
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

    // MARK: Private

    private static func make(
        target: LoadPrescription,
        current: LoadPrescription,
        stance: ProgressionStance,
        reason: String,
        blockedBy: [ProgressionGate],
        laterality: SetLaterality,
        pendingResolveID: UUID?
    ) -> ProgressionResult {
        ProgressionResult(
            target: target,
            current: current,
            stance: stance,
            reason: reason,
            blockedBy: blockedBy,
            laterality: laterality,
            pendingResolveID: pendingResolveID
        )
    }

    private static func holdReason(
        latest: TrainingSessionSnapshot,
        loadLbs: Double?
    ) -> String {
        if peakPain(in: latest) == nil {
            return reasonPainUnlogged
        }
        let floor = LoadPrescription(workingSets: defaultSets, reps: repFloor, loadLbs: loadLbs)
        if !hitTopReps(latest, target: floor) {
            return reasonShortReps
        }
        if isCleanHit(latest, loadLbs: loadLbs) {
            return reasonOneClean
        }
        return reasonHolding
    }

    private static func isCleanHit(
        _ session: TrainingSessionSnapshot,
        loadLbs: Double?
    ) -> Bool {
        switch session.response24h {
        case .better, .same:
            break
        case .pending, .worse, .notApplicable:
            return false
        }
        guard let pain = peakPain(in: session), pain <= painDuringLimit else { return false }
        let floor = LoadPrescription(workingSets: defaultSets, reps: repFloor, loadLbs: loadLbs)
        return hitTopReps(session, target: floor)
    }

    private static func sessionsAtLoad(
        _ history: [TrainingSessionSnapshot],
        loadLbs: Double?
    ) -> [TrainingSessionSnapshot] {
        history.filter { sameLoad(inferredLoad($0), loadLbs) }
    }

    private static func inferredLoad(_ session: TrainingSessionSnapshot) -> Double? {
        inferPrescription(session)?.loadLbs
    }

    private static func sameLoad(_ lhs: Double?, _ rhs: Double?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            return abs(left - right) < 0.001
        default:
            return false
        }
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
