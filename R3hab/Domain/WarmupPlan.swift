import Foundation

/// One warm-up step. A step is a hold (seconds) or a rep set (reps).
/// Load is optional. No load means body weight or the lightest setting.
///
/// A step saves as one `ResistanceSet` row with `isWarmup = true`.
/// A hold row has `reps = 1` and `holdSeconds`. A rep row has `reps` and
/// no `holdSeconds`. This is the same row shape the app already stores,
/// so there is no new stored field.
struct WarmupStep: Equatable, Identifiable, Sendable {
    enum Kind: String, CaseIterable, Equatable, Sendable {
        case hold
        case reps

        var title: String {
            switch self {
            case .hold: return "Hold"
            case .reps: return "Reps"
            }
        }
    }

    var id: UUID
    var kind: Kind
    /// Used when `kind == .hold`. Kept when the kind changes.
    var seconds: Int
    /// Used when `kind == .reps`. Kept when the kind changes.
    var reps: Int
    var loadLbs: Double?
    /// True while the values are the same as the last session.
    var fromLastSession: Bool

    init(
        id: UUID = UUID(),
        kind: Kind,
        seconds: Int = WarmupPlan.holdSeconds,
        reps: Int = 3,
        loadLbs: Double? = nil,
        fromLastSession: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.seconds = seconds
        self.reps = reps
        self.loadLbs = loadLbs
        self.fromLastSession = fromLastSession
    }

    static func hold(seconds: Int = WarmupPlan.holdSeconds, loadLbs: Double? = nil) -> WarmupStep {
        WarmupStep(kind: .hold, seconds: seconds, loadLbs: loadLbs)
    }

    static func reps(_ reps: Int, loadLbs: Double?) -> WarmupStep {
        WarmupStep(kind: .reps, reps: reps, loadLbs: loadLbs)
    }

    /// Short text, for example "Hold 30 s" or "3 × 25 lb".
    var line: String {
        switch kind {
        case .hold:
            if let loadLbs, loadLbs > 0 {
                return "Hold \(seconds) s @ \(LoadCopy.labeled(loadLbs))"
            }
            return "Hold \(seconds) s"
        case .reps:
            if let loadLbs, loadLbs > 0 {
                return "\(reps) × \(LoadCopy.labeled(loadLbs))"
            }
            return "\(reps) reps"
        }
    }

    func resistanceSet() -> ResistanceSet {
        let load = (loadLbs ?? 0) > 0 ? loadLbs : nil
        switch kind {
        case .hold:
            return ResistanceSet(reps: 1, loadLbs: load, holdSeconds: max(seconds, 1), isWarmup: true)
        case .reps:
            return ResistanceSet(reps: max(reps, 1), loadLbs: load, holdSeconds: nil, isWarmup: true)
        }
    }
}

/// Where the warm-up values came from.
enum WarmupSource: Equatable, Sendable {
    /// Copied from the most recent session that has a warm-up.
    case lastSession
    /// Made from today's working load.
    case template
    /// No history and no working load. The template steps have no load.
    case blank

    var label: String {
        switch self {
        case .lastSession: return "From last session"
        case .template: return "From today's load"
        case .blank: return "Standard warm-up"
        }
    }
}

struct WarmupPlan: Equatable, Sendable {
    static let holdSeconds = 30
    static let holdSecondsStep = 5
    static let maxSteps = 6
    /// Old warm-up rows can store "2 × 30 s". Do not make more steps than this from one row.
    static let maxHoldsFromOneRow = 4

    /// One step per node on the warm-up stepper. Prefill copies the plan here.
    /// Next records the values on screen and goes to the next step.
    var steps: [WarmupStep]
    /// The plan (last session or template). The target for each step.
    /// A step past the end of the plan is an extra step (from the "+" node).
    var planned: [WarmupStep]
    var source: WarmupSource

    init(
        steps: [WarmupStep] = [],
        planned: [WarmupStep] = [],
        source: WarmupSource
    ) {
        self.steps = steps
        self.planned = planned
        self.source = source
    }

    var line: String {
        steps.isEmpty ? "No steps" : steps.map(\.line).joined(separator: " · ")
    }

    // MARK: Template

    /// Round to the nearest machine step, for example 5 lb.
    static func roundLoad(_ load: Double, step: Double) -> Double {
        guard step > 0 else { return load }
        return (load / step).rounded() * step
    }

    /// Hold 30 s with no load, then about 50% × 3, then about 75% × 2.
    /// Loads round to `loadStep`. With no working load, the rep steps have no load.
    static func template(workingLoad: Double?, loadStep: Double) -> [WarmupStep] {
        guard let workingLoad, workingLoad > 0 else {
            return [.hold(), .reps(3, loadLbs: nil), .reps(2, loadLbs: nil)]
        }
        let floor = loadStep > 0 ? loadStep : 0
        let half = min(max(roundLoad(workingLoad * 0.5, step: loadStep), floor), workingLoad)
        let most = min(max(roundLoad(workingLoad * 0.75, step: loadStep), half), workingLoad)
        return [.hold(), .reps(3, loadLbs: half), .reps(2, loadLbs: most)]
    }

    // MARK: Prefill

    /// Steps from the newest saved session that has warm-up rows. Nil when no session has one.
    static func lastWarmup(from sessions: [TrainingSessionSnapshot]) -> [WarmupStep]? {
        let ordered = sessions
            .filter(\.isFinalized)
            .sorted { ($0.date, $0.createdAt) > ($1.date, $1.createdAt) }
        for session in ordered {
            let steps = steps(from: session.resistanceSets)
            if !steps.isEmpty { return steps }
        }
        return nil
    }

    /// Turns saved warm-up rows into steps. A right-side row is the copy of
    /// its left-side row, so it is not a new step.
    static func steps(from rows: [ResistanceSet]) -> [WarmupStep] {
        var steps: [WarmupStep] = []
        for row in rows where row.isWarmup && row.side != .right {
            if let hold = row.holdSeconds, hold > 0 {
                let count = min(max(row.reps ?? 1, 1), maxHoldsFromOneRow)
                for _ in 0..<count {
                    var step = WarmupStep.hold(seconds: hold, loadLbs: row.loadLbs)
                    step.fromLastSession = true
                    steps.append(step)
                }
            } else if let reps = row.reps, reps > 0 {
                var step = WarmupStep.reps(reps, loadLbs: row.loadLbs)
                step.fromLastSession = true
                steps.append(step)
            }
        }
        return Array(steps.prefix(maxSteps))
    }

    /// 1. The last saved warm-up, if there is one.
    /// 2. Else the template from today's working load.
    /// 3. Else the template with no load: hold, then 3 reps, then 2 reps.
    /// The steps start as a copy of the plan. There is always at least one step.
    static func prefill(
        sessions: [TrainingSessionSnapshot],
        workingLoad: Double?,
        loadStep: Double
    ) -> WarmupPlan {
        let plan: [WarmupStep]
        let source: WarmupSource
        if let last = lastWarmup(from: sessions) {
            plan = last
            source = .lastSession
        } else if let workingLoad, workingLoad > 0 {
            plan = template(workingLoad: workingLoad, loadStep: loadStep)
            source = .template
        } else {
            plan = template(workingLoad: nil, loadStep: loadStep)
            source = .blank
        }
        return WarmupPlan(steps: plan, planned: plan, source: source)
    }

    /// The planned values for step `index`. Nil for an extra step.
    func target(at index: Int) -> WarmupStep? {
        planned.indices.contains(index) ? planned[index] : nil
    }

    /// True for a step that the "+" node added.
    func isExtra(at index: Int) -> Bool {
        index >= planned.count
    }

    /// Default reps when the kind toggle is Reps.
    static let defaultReps = 3
    static let minHoldSeconds = 5
    static let maxHoldSeconds = 120
    static let minReps = 1
    static let maxReps = 20

    /// Hold ruler: 5, 10, … 120 seconds.
    static var holdSecondsIndexCount: Int {
        ((maxHoldSeconds - minHoldSeconds) / holdSecondsStep) + 1
    }

    static func holdSecondsIndex(_ seconds: Int) -> Int {
        let clamped = min(max(seconds, minHoldSeconds), maxHoldSeconds)
        let stepped = ((clamped - minHoldSeconds + holdSecondsStep / 2) / holdSecondsStep) * holdSecondsStep + minHoldSeconds
        return min(max((stepped - minHoldSeconds) / holdSecondsStep, 0), holdSecondsIndexCount - 1)
    }

    static func holdSeconds(atIndex index: Int) -> Int {
        let i = min(max(index, 0), holdSecondsIndexCount - 1)
        return minHoldSeconds + i * holdSecondsStep
    }

    // MARK: Edits

    /// The "+" node. Adds a copy of the last step, or a 30 s hold when there are no steps.
    /// Returns false when the stepper is full.
    @discardableResult
    mutating func addStep() -> Bool {
        guard steps.count < Self.maxSteps else { return false }
        if let last = steps.last {
            steps.append(WarmupStep(kind: last.kind, seconds: last.seconds, reps: last.reps, loadLbs: last.loadLbs))
        } else {
            steps.append(.hold())
        }
        return true
    }

    /// Removes the extra steps. A skipped warm-up keeps only the plan.
    mutating func removeExtraSteps() {
        if steps.count > planned.count {
            steps = Array(steps.prefix(planned.count))
        }
    }

    /// Delete set. The plan entry goes too, so each later step keeps its own target.
    mutating func removeStep(at index: Int) {
        guard steps.indices.contains(index) else { return }
        steps.remove(at: index)
        if planned.indices.contains(index) {
            planned.remove(at: index)
        }
    }

    /// Changes one step. The step is no longer marked as from the last session.
    mutating func update(id: UUID, _ change: (inout WarmupStep) -> Void) {
        guard let index = steps.firstIndex(where: { $0.id == id }) else { return }
        var step = steps[index]
        change(&step)
        step.fromLastSession = false
        steps[index] = step
    }

    func resistanceSets() -> [ResistanceSet] {
        steps.map { $0.resistanceSet() }
    }
}
