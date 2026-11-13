import Foundation

/// One HSR working prescription. Sets are conceptual pairs, not L/R rows.
struct LoadPrescription: Equatable, Sendable {
    var workingSets: Int
    var reps: Int
    var loadLbs: Double?
    var holdSeconds: Int? = nil
    var restSeconds: Int? = nil
    var tempo: String? = nil

    var displayLine: String {
        let dose: String
        if let holdSeconds {
            dose = "\(workingSets)×\(holdSeconds)s"
        } else {
            dose = "\(workingSets)×\(reps)"
        }
        guard let loadLbs else { return dose }
        return "\(dose) @ \(LoadCopy.labeled(loadLbs))"
    }

    var todayLine: String {
        "Today: \(displayLine)"
    }

    /// Last logged dose. Not a computed next load.
    var lastTimeLine: String {
        "Last session: \(displayLine)"
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

    /// Increase opens the form at the recommended load (last load + one increment).
    /// Hold and decrease open at the last working load.
    var label: String {
        switch self {
        case .hold: return "Hold the load"
        case .advance: return "Increase the load"
        case .drop: return "Decrease the load"
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
    /// The lowest reps logged last session, when they were below today's rep target.
    /// Nil when the reps reached the target.
    var lastLoggedReps: Int? = nil
    /// Set when the last session's pain during was over 3. The load rule does not drop for this alone.
    var painWarning: String? = nil

    /// Reason on the gold Next Up card.
    /// Hold never adds a weight. A change-load stance names a suggested
    /// weight only when the engine already produced one that is not the
    /// last working load. Otherwise this is `reason`.
    var cardReason: String {
        guard let pounds = suggestedChangeLoadLbs else { return reason }
        return "\(stance.label). Try \(LoadCopy.labeled(pounds))."
    }

    /// Next weight, in pounds, when it differs from the last working load.
    /// Hold does not suggest a number. A missing load is not a suggestion.
    var suggestedChangeLoadLbs: Double? {
        guard stance != .hold else { return nil }
        guard let next = target.loadLbs else { return nil }
        if let last = current.loadLbs, abs(next - last) < 0.001 {
            return nil
        }
        return next
    }
}

/// QL diary helpers. Clinical targets are TBD — these do not advise
/// increase or drop, and they do not snap sets into the patellar 3×8–12 band.
enum QLLoggingStub {
    static let clinicalTargetNote = "Clinical targets are not set."

    /// Last logged load and reps for a weighted QL move. Blank when nothing is logged yet.
    static func lastWeighted(
        sessions: [TrainingSessionSnapshot],
        title: String
    ) -> LoadPrescription? {
        let matches = SessionDraft.finalized(sessions)
            .filter { ProgressionEngine.matchesPrimaryLoad($0, title: title) }
            .sorted { $0.createdAt > $1.createdAt }
        guard let latest = matches.first else { return nil }
        let pairs = SessionSummary.groupWorkSets(latest.resistanceSets.filter { !$0.isWarmup })
        guard let pair = pairs.last, pair.leftLoad != nil || pair.reps != nil else { return nil }
        return LoadPrescription(
            workingSets: max(pairs.count, 1),
            reps: pair.reps ?? 0,
            loadLbs: pair.leftLoad
        )
    }

    /// Display-only step reminder. `stepNearNormalMin` is the existing settings
    /// number, reused as a label — not a QL clinical prescription.
    static func stepTargetLine(stepNearNormalMin: Int) -> String {
        "The step target is \(stepNearNormalMin). \(clinicalTargetNote)"
    }
}

enum SessionPrefill {
    static func workSets(
        from target: LoadPrescription,
        laterality: SetLaterality
    ) -> [ResistanceSet] {
        let reps = target.holdSeconds == nil ? target.reps : 1
        return (0..<target.workingSets).flatMap { _ in
            SessionSummary.makePair(
                reps: reps,
                loadLbs: target.loadLbs,
                holdSeconds: target.holdSeconds,
                isWarmup: false
            )
        }
    }

    static func warmupSet(loadLbs: Double?) -> ResistanceSet {
        ResistanceSet(reps: 2, loadLbs: loadLbs, holdSeconds: 30, isWarmup: true)
    }
}

/// Load advice for the 12-week plan. Reps come from the week. Weight goes up
/// once each new week when the next morning stayed at baseline. A morning
/// above baseline drops the load for one session. Pain over 3 warns, and
/// does not drop the load by itself.
enum ProgressionEngine {
    static let loadIncrementLbs = TwelveWeekPlan.loadIncrementLbs
    static let painDuringLimit = PainRule.duringLimit
    static let reasonStart = TwelveWeekPlan.reasonPickLoad
    static let reasonOutsidePlan = TwelveWeekPlan.reasonOutsidePlan
    static let reasonAwaitMorning = TwelveWeekPlan.reasonAwaitMorning

    static func today(
        sessions: [TrainingSessionSnapshot],
        primaryLoadTitle: String = PrimaryLoadCatalog.seatedExtension.title,
        asOf: Date,
        calendar: Calendar = .current,
        programStart: Date? = nil,
        checkIns: [DailyCheckInSnapshot] = [],
        exercise: PlanExerciseKind? = nil,
        overrides: [PlanSessionOverride] = []
    ) -> ProgressionResult {
        let start = programStart ?? calendar.startOfDay(for: asOf)
        let week = TwelveWeekPlan.programWeek(start: start, on: asOf, calendar: calendar)
        let kind = exercise ?? inferredKind(title: primaryLoadTitle, week: week)
        guard let kind else {
            let seed = LoadPrescription(workingSets: 3, reps: 8, loadLbs: nil)
            return ProgressionResult(
                target: seed,
                current: seed,
                stance: .hold,
                reason: reasonOutsidePlan,
                blockedBy: [],
                laterality: .bilateral,
                pendingResolveID: nil
            )
        }
        let advice = TwelveWeekPlan.advise(
            kind: kind,
            programStart: start,
            sessions: sessions,
            checkIns: checkIns,
            asOf: asOf,
            calendar: calendar,
            overrides: overrides
        )
        return ProgressionResult(
            target: advice.target,
            current: advice.last ?? advice.target,
            stance: advice.stance,
            reason: advice.reason,
            blockedBy: advice.blockedBy,
            laterality: advice.laterality,
            pendingResolveID: advice.pendingResolveID,
            lastLoggedReps: advice.lastLoggedReps,
            painWarning: advice.painWarning
        )
    }

    static func inferredKind(title: String, week: Int) -> PlanExerciseKind? {
        let text = title.lowercased()
        if text.contains("hip thrust") || text.contains("side bend") || text == "walking" {
            return nil
        }
        if text.contains("pogo") { return .pogoHop }
        if text.contains("box jump") { return .boxJumpUp }
        if text.contains("landing") { return .landing }
        if text.contains("spanish") { return .spanishSquat }
        if text.contains("hip abduction") { return .hipAbduction }
        if text.contains("calf") { return .calfRaise }
        if text.contains("single-leg") && text.contains("press") { return .singleLegPress }
        if text.contains("leg press") {
            return TwelveWeekPlan.contentWeek(week) <= 2 ? .singleLegPress : .legPress
        }
        if text.contains("seated") {
            return TwelveWeekPlan.contentWeek(week) <= 2 ? .isometricLegExtension : .legExtension
        }
        return nil
    }

    static func evaluateAfterSave(
        sessions: [TrainingSessionSnapshot],
        primaryLoadTitle: String = PrimaryLoadCatalog.seatedExtension.title,
        asOf: Date,
        calendar: Calendar = .current,
        programStart: Date? = nil,
        checkIns: [DailyCheckInSnapshot] = []
    ) -> ProgressionResult {
        today(
            sessions: sessions,
            primaryLoadTitle: primaryLoadTitle,
            asOf: asOf,
            calendar: calendar,
            programStart: programStart,
            checkIns: checkIns
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

    /// What the session actually logged: the most common working-set load and the lowest reps.
    /// A tie between loads goes to the load of the later set. Example: guidance 65 lb, logged
    /// 65 then 60 → 60 lb. Before this rule a tie went to the heaviest load, so a hold day
    /// showed the earlier guidance (65 lb) instead of the load you could do.
    static func inferPrescription(_ session: TrainingSessionSnapshot) -> LoadPrescription? {
        let pairs = SessionSummary.groupWorkSets(session.resistanceSets.filter { !$0.isWarmup })
        guard !pairs.isEmpty else { return nil }
        let minReps = pairs.compactMap(\.reps).min() ?? 8
        let loads = pairs.compactMap(\.leftLoad)
        return LoadPrescription(workingSets: pairs.count, reps: minReps, loadLbs: modalLoad(loads))
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

    /// The recommended load for an increase day: one increment more than the last working load.
    /// With no logged load there is no number to increase, so the target stays without a load.
    static func increased(_ current: LoadPrescription) -> LoadPrescription {
        guard let last = current.loadLbs else { return current }
        var next = current
        next.loadLbs = last + loadIncrementLbs
        return next
    }

    /// Most common load, in set order. A tie goes to the load of the later set.
    static func modalLoad(_ loads: [Double]) -> Double? {
        guard !loads.isEmpty else { return nil }
        var counts: [Double: Int] = [:]
        var lastIndex: [Double: Int] = [:]
        for (index, load) in loads.enumerated() {
            counts[load, default: 0] += 1
            lastIndex[load] = index
        }
        return counts.max { a, b in
            if a.value != b.value { return a.value < b.value }
            return (lastIndex[a.key] ?? 0) < (lastIndex[b.key] ?? 0)
        }?.key
    }
}

private extension TrainingSessionSnapshot {
    var chartLoad: Double? {
        ResistanceMath.chartMaxLoad(work: resistanceSets)
    }
}
