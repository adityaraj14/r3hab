import Foundation

/// Which logging prototype is on screen. The standard form stays the default.
enum SessionLogPrototypeKind: String, CaseIterable, Identifiable, Equatable, Sendable {
    case guided
    case live
    case quick

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .guided: return "Guided steps"
        case .live: return "Live tracker"
        case .quick: return "Quick log"
        }
    }

    var settingsTitle: String { "Prototype: \(menuTitle)" }

    var screenTitle: String {
        switch self {
        case .guided: return "Guided"
        case .live: return "Live"
        case .quick: return "Quick log"
        }
    }
}

/// Stable identifiers for the prototype screenshot UI test.
enum SessionPrototypeAccessibility {
    static let menu = "session-log-prototype-menu"
    static let openStandard = "prototype-open-standard"
    static let cancel = "prototype-cancel"
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

    static let liveDose = "prototype-live-dose"
    static let liveDone = "prototype-live-done-set"
    static let liveRest = "prototype-live-rest"
    static let liveSkipRest = "prototype-live-skip-rest"
    static let liveRepsMinus = "prototype-live-reps-minus"
    static let liveRepsPlus = "prototype-live-reps-plus"
    static let liveLoadMinus = "prototype-live-load-minus"
    static let liveLoadPlus = "prototype-live-load-plus"
    static let livePain = "prototype-live-pain"
    static let liveSlider = "prototype-live-pain-slider"

    static let quickPlan = "prototype-quick-plan"
    static let quickYes = "prototype-quick-yes"
    static let quickAdjust = "prototype-quick-adjust"
    static let quickAdjustPanel = "prototype-quick-adjust-panel"
    static let quickAdjustDone = "prototype-quick-adjust-done"
    static let quickPain = "prototype-quick-pain"

    static func open(_ kind: SessionLogPrototypeKind) -> String {
        "prototype-open-\(kind.rawValue)"
    }

    static func screen(_ kind: SessionLogPrototypeKind) -> String {
        "prototype-\(kind.rawValue)-screen"
    }

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

    static func quickReps(set: Int, reps: Int) -> String {
        "prototype-quick-set-\(set)-reps-\(reps)"
    }

    static func quickLoad(set: Int, token: String) -> String {
        "prototype-quick-set-\(set)-load-\(token)"
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

    var quickQuestion: String { "Did you do today's plan: \(planLine)?" }

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
    static let restSeconds = 90
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

    static func guidedPrompts(setCount: Int) -> [GuidedPrompt] {
        var steps: [GuidedPrompt] = [.exercise, .warmup]
        steps.append(contentsOf: (0..<setCount).map { .set($0) })
        steps.append(contentsOf: [.pain, .notes, .review])
        return steps
    }

    static func repChoices(around reps: Int) -> [Int] {
        Array(Set([6, 8, 10, 12, 15, reps].filter { $0 > 0 })).sorted()
    }

    static func loadChoices(around load: Double?) -> [Double?] {
        guard let load else { return [nil, 10, 20, 30, 40, 50] }
        let raw = [-10.0, -5, 0, 5, 10].map { max(0, load + $0) }
        var unique: [Double] = []
        for value in raw {
            if unique.contains(where: { abs($0 - value) < 0.001 }) { continue }
            unique.append(value)
        }
        return unique.sorted().map { Optional($0) }
    }

    static func bumpReps(_ reps: Int, by delta: Int) -> Int {
        max(1, reps + delta)
    }

    static func bumpLoad(_ load: Double?, by delta: Double) -> Double? {
        let base = load ?? 0
        let next = base + delta
        if next < 0 { return load == nil ? nil : 0 }
        if next == 0 && load == nil { return nil }
        return next
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
