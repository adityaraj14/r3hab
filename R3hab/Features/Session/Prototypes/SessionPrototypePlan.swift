import Foundation

/// Stable identifiers for the guided session form and its UI tests.
enum SessionPrototypeAccessibility {
    static let screen = "guided-session-screen"
    static let cancel = "prototype-cancel"
    static let saveDraft = "guided-save-draft"
    static let progress = "prototype-progress"
    static let next = "prototype-next"
    static let back = "prototype-back"
    static let save = "prototype-save"

    static let guidedExercise = "prototype-guided-exercise"
    static let guidedWarmup = "prototype-guided-warmup"
    static let guidedWarmupYes = "prototype-guided-warmup-yes"
    static let guidedWarmupSkip = "prototype-guided-warmup-skip"
    static let guidedSame = "prototype-guided-same-as-target"
    static let guidedWarmupAdd = "prototype-guided-warmup-add"
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
    case warmup
    case set(Int)
    case pain
    case notes
    case review

    var accessibilityIdentifier: String {
        switch self {
        case .exercise: return SessionPrototypeAccessibility.guidedExercise
        case .warmup: return SessionPrototypeAccessibility.guidedWarmup
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

    func aligned(to target: LoadPrescription) -> PrototypeSetDraft {
        var copy = self
        copy.reps = target.reps
        copy.loadLbs = target.loadLbs
        return copy
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
    static let loadStep = 5.0
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

    /// How many working-set nodes are filled on the set stepper.
    /// Sets before the current set index are logged. Past the last set, all are logged.
    static func setStepperFilled(currentSetIndex: Int?, setCount: Int) -> Int {
        let total = max(setCount, 0)
        guard let currentSetIndex else { return total }
        return min(max(currentSetIndex, 0), total)
    }

    static func guidedPrompts(setCount: Int) -> [GuidedPrompt] {
        var steps: [GuidedPrompt] = [.exercise, .warmup]
        steps.append(contentsOf: (0..<setCount).map { .set($0) })
        steps.append(contentsOf: [.pain, .notes, .review])
        return steps
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
