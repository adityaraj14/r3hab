import Foundation

/// Stable identifiers for the guided session form and its UI tests.
enum SessionPrototypeAccessibility {
    static let screen = "guided-session-screen"
    static let saveDraft = "guided-save-draft"
    static let next = "prototype-next"
    static let back = "prototype-back"
    static let save = "prototype-save"

    static let guidedExercise = "prototype-guided-exercise"
    static let guidedWarmup = "prototype-guided-warmup"
    static let guidedWarmupSkip = "prototype-guided-warmup-skip"
    /// The "+" node at the end of the warm-up stepper.
    static let guidedWarmupAdd = "prototype-guided-warmup-add"
    static let guidedWarmupRemove = "prototype-guided-warmup-remove"
    static let guidedWarmupSource = "prototype-guided-warmup-source"
    static let guidedPain = "prototype-guided-pain"
    static let guidedNotes = "prototype-guided-notes"
    static let guidedReview = "prototype-guided-review"

    static func guidedSet(_ index: Int) -> String {
        "prototype-guided-set-\(index + 1)"
    }

    static func warmupStep(_ index: Int) -> String {
        "prototype-guided-warmup-step-\(index + 1)"
    }

    static func warmupStep(_ index: Int, _ part: String) -> String {
        "prototype-guided-warmup-step-\(index + 1)-\(part)"
    }

    /// `field` is "reps" or "load".
    static func setRuler(set: Int, field: String) -> String {
        "prototype-guided-set-\(set + 1)-\(field)-ruler"
    }

    static func painChip(_ score: Int) -> String {
        "prototype-pain-chip-\(score)"
    }
}

enum GuidedPrompt: Equatable, Sendable {
    case exercise
    /// Warm-up step (0-based), one per node on the warm-up stepper.
    case warmup(Int)
    case set(Int)
    case pain
    case notes
    case review

    var accessibilityIdentifier: String {
        switch self {
        case .exercise: return SessionPrototypeAccessibility.guidedExercise
        case .warmup(let index): return SessionPrototypeAccessibility.warmupStep(index)
        case .set(let index): return SessionPrototypeAccessibility.guidedSet(index)
        case .pain: return SessionPrototypeAccessibility.guidedPain
        case .notes: return SessionPrototypeAccessibility.guidedNotes
        case .review: return SessionPrototypeAccessibility.guidedReview
        }
    }
}

struct PrototypeSetDraft: Equatable, Identifiable, Sendable {
    var id: UUID
    var reps: Int
    var loadLbs: Double?

    var doseLabel: String {
        if let loadLbs {
            return "\(reps) × \(LoadCopy.labeled(loadLbs))"
        }
        return "\(reps) reps"
    }

    func matchesTarget(_ target: LoadPrescription) -> Bool {
        guard reps == target.reps else { return false }
        switch (loadLbs, target.loadLbs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            return abs(left - right) < 0.001
        default:
            return false
        }
    }
}

struct SessionPrototypeDraft: Equatable, Sendable {
    var exerciseTitle: String
    var phase: RehabPhase
    var sessionType: SessionType
    var target: LoadPrescription
    var stanceLabel: String
    var reason: String
    var includeWarmup: Bool
    var warmup: WarmupPlan
    var sets: [PrototypeSetDraft]
    var painDuring: Int?
    var notes: String

    var planLine: String { target.displayLine }

    /// The guided steps for this draft: exercise, each warm-up step, each set, pain, notes, review.
    var prompts: [GuidedPrompt] {
        SessionPrototypePlan.guidedPrompts(warmupCount: warmup.steps.count, setCount: sets.count)
    }

    var perSetTargetLine: String {
        if let load = target.loadLbs {
            return "Target \(target.reps) × \(LoadCopy.labeled(load))"
        }
        return "Target \(target.reps) reps"
    }

    var warmupLine: String { warmup.line }

    func resistanceSets() -> [ResistanceSet] {
        var rows: [ResistanceSet] = []
        if includeWarmup {
            rows.append(contentsOf: warmup.resistanceSets())
        }
        for set in sets {
            rows.append(contentsOf: SessionSummary.makePair(
                reps: set.reps,
                loadLbs: set.loadLbs,
                holdSeconds: nil,
                isWarmup: false
            ))
        }
        return rows
    }

    func whatIDid() -> String {
        var parts = [exerciseTitle]
        if let compact = SessionSummary.compactResistance(resistanceSets()) {
            parts.append(compact)
        }
        return parts.joined(separator: " · ")
    }
}

enum SessionPrototypePlan {
    static let loadStep = ProgressionEngine.loadIncrementLbs
    /// Same sentence the session form already shows under pain.
    static let painDuringNote = "Record the pain during the session. Use 0 to 10. R3hab sends a reminder in about 30 minutes. Then record the pain after the session."
    static let under48hWarning = "Your last hard session was less than 48 hours ago. You can save. This is only a warning."
    /// Highest values on the set rulers.
    static let maxReps = 30
    static let maxLoad = 300.0

    static func make(
        sessions: [TrainingSessionSnapshot],
        phase: RehabPhase,
        asOf: Date,
        calendar: Calendar = .current
    ) -> SessionPrototypeDraft {
        let title = PrimaryLoadCatalog.seatedExtension.title
        let result = ProgressionEngine.today(
            sessions: sessions,
            primaryLoadTitle: title,
            asOf: asOf,
            calendar: calendar
        )
        let prefilled = SessionPrefill.workSets(from: result.target, laterality: result.laterality)
        let pairs = SessionSummary.groupWorkSets(prefilled)
        let sets: [PrototypeSetDraft]
        if pairs.isEmpty {
            let count = max(result.target.workingSets, 1)
            sets = (0..<count).map { _ in
                PrototypeSetDraft(id: UUID(), reps: result.target.reps, loadLbs: result.target.loadLbs)
            }
        } else {
            sets = pairs.map { pair in
                PrototypeSetDraft(
                    id: pair.id,
                    reps: pair.reps ?? result.target.reps,
                    loadLbs: pair.leftLoad
                )
            }
        }
        return SessionPrototypeDraft(
            exerciseTitle: title,
            phase: phase,
            sessionType: .hsrStrength,
            target: result.target,
            stanceLabel: result.stance.label,
            reason: result.reason,
            includeWarmup: false,
            warmup: WarmupPlan.prefill(
                sessions: sessions,
                workingLoad: result.target.loadLbs,
                loadStep: loadStep
            ),
            sets: sets,
            painDuring: nil,
            notes: ""
        )
    }

    static func setsForSave(_ draft: SessionPrototypeDraft) -> [ResistanceSet] {
        ProgressionEngine.applySessionPain(draft.painDuring, to: draft.resistanceSets())
    }

    static func guidedPrompts(warmupCount: Int, setCount: Int) -> [GuidedPrompt] {
        var steps: [GuidedPrompt] = [.exercise]
        steps.append(contentsOf: (0..<max(warmupCount, 0)).map { .warmup($0) })
        steps.append(contentsOf: (0..<max(setCount, 0)).map { .set($0) })
        steps.append(contentsOf: [.pain, .notes, .review])
        return steps
    }

    // MARK: Guided navigation
    // `furthest` is the first step the user has not finished. Steps before it are done.

    /// A step before the first unfinished step is done.
    static func isStepDone(_ index: Int, furthest: Int) -> Bool {
        index >= 0 && index < furthest
    }

    /// Next records the step and goes forward: to the next step, or back to the
    /// first unfinished step when the user opened an earlier step.
    static func nextIndex(current: Int, furthest: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(current + 1, furthest), count - 1)
    }

    /// A tap on a stepper node. Only a done node opens its step.
    /// The current node and later nodes do not respond. Nil when nothing changes.
    static func nodeTarget(tapped: Int, current: Int, furthest: Int) -> Int? {
        guard isStepDone(tapped, furthest: furthest), tapped != current else { return nil }
        return tapped
    }

    enum StepSwipe: Equatable, Sendable {
        case back
        case forward
    }

    /// A step swipe must move this far, mostly sideways.
    static let stepSwipeMinDistance: Double = 48
    /// On the warm-up and set steps, a step swipe must start this close to a screen edge.
    /// The rulers start inside this edge, so a drag on a ruler only moves the ruler.
    static let stepSwipeEdge: Double = 24

    /// The direction of a step swipe, or nil when the drag is not a step swipe.
    /// A swipe to the left goes forward. A swipe to the right goes back.
    static func stepSwipe(startX: Double, width: Double, dx: Double, dy: Double, hasRulers: Bool) -> StepSwipe? {
        guard abs(dx) >= stepSwipeMinDistance, abs(dx) > abs(dy) else { return nil }
        if hasRulers {
            let nearEdge = startX <= stepSwipeEdge || startX >= width - stepSwipeEdge
            guard nearEdge else { return nil }
        }
        return dx < 0 ? .forward : .back
    }

    /// Where a step swipe goes. Back: one step back, not before step 1.
    /// Forward: one step, not past the first unfinished step (`furthest`).
    /// A swipe does not record a step. Only Next moves past `furthest`. Nil when nothing changes.
    static func swipeTarget(_ swipe: StepSwipe, current: Int, furthest: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        switch swipe {
        case .back:
            return current > 0 ? current - 1 : nil
        case .forward:
            let limit = min(max(furthest, 0), count - 1)
            return current < limit ? current + 1 : nil
        }
    }

    /// After the delete of the step at `deleted`, go to the first unfinished step.
    static func afterDelete(deleted: Int, furthest: Int, count: Int) -> (current: Int, furthest: Int) {
        let shifted = deleted < furthest ? furthest - 1 : furthest
        let next = min(max(shifted, 0), max(count - 1, 0))
        return (next, next)
    }

    /// After the finger lifts, a flick adds at most this many steps.
    static let rulerMaxFlickSteps = 2

    /// Ruler position while the finger is down. It follows the finger 1 to 1.
    /// Swipe left (negative points) to go up.
    static func rulerPosition(start: Double, dragPoints: Double, tickWidth: Double, count: Int) -> Double {
        guard tickWidth > 0, count > 0 else { return 0 }
        return min(max(start - dragPoints / tickWidth, 0), Double(count - 1))
    }

    /// Extra steps from the flick speed. `momentumPoints` is the travel the
    /// system predicts after the finger lifts. A quarter of it counts, and
    /// never more than `rulerMaxFlickSteps`.
    static func rulerFlickSteps(momentumPoints: Double, tickWidth: Double) -> Int {
        guard tickWidth > 0 else { return 0 }
        let raw = (-momentumPoints / tickWidth / 4).rounded()
        let limit = Double(rulerMaxFlickSteps)
        return Int(min(max(raw, -limit), limit))
    }

    /// Where the ruler stops: the nearest value, plus the flick steps.
    static func rulerFinalIndex(position: Double, momentumPoints: Double, tickWidth: Double, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let landed = Int(position.rounded()) + rulerFlickSteps(momentumPoints: momentumPoints, tickWidth: tickWidth)
        return min(max(landed, 0), count - 1)
    }

    /// Load after `ticks` machine steps (warm-up steppers and the load ruler). Stays in 0...maxLoad. Zero means no load.
    static func load(_ load: Double?, ticks: Int) -> Double? {
        let next = min(max((load ?? 0) + Double(ticks) * loadStep, 0), maxLoad)
        return next > 0 ? next : nil
    }

    /// Ruler position for a load. Position 0 is no load.
    static func loadIndex(_ load: Double?) -> Int {
        Int(((load ?? 0) / loadStep).rounded())
    }

    static func load(atIndex index: Int) -> Double? {
        load(nil, ticks: index)
    }

    static var loadIndexCount: Int { Int(maxLoad / loadStep) + 1 }

    /// "+2 reps", "−1 rep", or "Target".
    static func repsDelta(_ reps: Int, target: Int) -> String {
        let delta = reps - target
        if delta == 0 { return "Target" }
        let sign = delta > 0 ? "+" : "\u{2212}"
        let noun = abs(delta) == 1 ? "rep" : "reps"
        return "\(sign)\(abs(delta)) \(noun)"
    }

    /// "+5 s", "−10 s", or "Target".
    static func secondsDelta(_ seconds: Int, target: Int) -> String {
        let delta = seconds - target
        if delta == 0 { return "Target" }
        let sign = delta > 0 ? "+" : "\u{2212}"
        return "\(sign)\(abs(delta)) s"
    }

    /// "+5 lb", "−10 lb", or "Target".
    static func loadDelta(_ load: Double?, target: Double?) -> String {
        let delta = (load ?? 0) - (target ?? 0)
        if abs(delta) < 0.001 { return "Target" }
        let sign = delta > 0 ? "+" : "\u{2212}"
        return "\(sign)\(LoadCopy.labeled(abs(delta)))"
    }

    static func loadToken(_ load: Double?) -> String {
        load.map { LoadCopy.formatted($0) } ?? "none"
    }
}
