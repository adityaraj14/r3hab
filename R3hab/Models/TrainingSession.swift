import Foundation
import SwiftData

@Model
final class TrainingSession {
    @Attribute(.unique) var id: UUID
    var date: Date
    var phaseRaw: String
    var typeRaw: String
    var whatIDid: String
    var painDuring: Int
    /// 0–10 when logged. `PainScore.notLogged` (−1) means after-pain is still outstanding.
    var painAfter: Int
    /// Legacy single-block fields (kept for migration / old rows).
    var sets: Int?
    var reps: Int?
    @Attribute(originalName: "loadKg")
    var loadLbs: Double?
    var holdSeconds: Int?
    var warmupReps: Int?
    var warmupHoldSeconds: Int?
    var warmupLoadLbs: Double?
    /// JSON array of `ResistanceSet` — preferred source for multi-set logging.
    var resistanceSetsJSON: String?
    /// Unused since the QL track was removed (all loads are knee). Kept for
    /// SwiftData schema stability and backup round-trips.
    var loadRegionRaw: String?
    /// Unused since the QL track was removed. Kept for schema stability.
    var trackRaw: String?
    var response24hRaw: String
    var decisionRaw: String?
    var notes: String
    var snoozedUntil: Date?
    var snoozeUsed: Bool
    var resolvedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    /// Existing rows stay `false` through lightweight migration.
    var isDraft: Bool = false

    var phase: RehabPhase {
        get { RehabPhase.normalized(rawValue: phaseRaw) }
        set { phaseRaw = newValue.rawValue }
    }

    var sessionType: SessionType {
        get { SessionType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var response24h: Response24h {
        get { Response24h(rawValue: response24hRaw) ?? .pending }
        set { response24hRaw = newValue.rawValue }
    }

    var decision: SessionDecision? {
        get {
            guard let decisionRaw else { return nil }
            return SessionDecision(rawValue: decisionRaw)
        }
        set { decisionRaw = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        phase: RehabPhase,
        sessionType: SessionType,
        whatIDid: String,
        painDuring: Int,
        painAfter: Int = PainScore.notLogged,
        sets: Int? = nil,
        reps: Int? = nil,
        loadLbs: Double? = nil,
        holdSeconds: Int? = nil,
        warmupReps: Int? = nil,
        warmupHoldSeconds: Int? = nil,
        warmupLoadLbs: Double? = nil,
        resistanceSets: [ResistanceSet] = [],
        calendar: Calendar = .current
    ) {
        self.id = id
        self.date = calendar.startOfDay(for: date)
        self.phaseRaw = phase.rawValue
        self.typeRaw = sessionType.rawValue
        self.whatIDid = whatIDid
        self.painDuring = painDuring
        self.painAfter = painAfter
        self.sets = sets
        self.reps = reps
        self.loadLbs = loadLbs
        self.holdSeconds = holdSeconds
        self.warmupReps = warmupReps
        self.warmupHoldSeconds = warmupHoldSeconds
        self.warmupLoadLbs = warmupLoadLbs
        self.trackRaw = "knee"
        self.loadRegionRaw = "knee"
        self.response24hRaw = Response24h.pending.rawValue
        self.decisionRaw = nil
        self.notes = ""
        self.snoozedUntil = nil
        self.snoozeUsed = false
        self.resolvedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isDraft = false
        if !resistanceSets.isEmpty {
            self.setResistanceSets(resistanceSets)
        }
    }

    // MARK: - Multi-set payload

    func resistanceSets() -> [ResistanceSet] {
        if let resistanceSetsJSON,
           let data = resistanceSetsJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ResistanceSet].self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        return legacyAsSets()
    }

    func setResistanceSets(_ sets: [ResistanceSet]) {
        if sets.isEmpty {
            resistanceSetsJSON = nil
            return
        }
        if let data = try? JSONEncoder().encode(sets),
           let str = String(data: data, encoding: .utf8) {
            resistanceSetsJSON = str
        }
        // Mirror first work set into legacy fields for older chart/export paths
        let work = sets.filter { !$0.isWarmup }
        let primary = work.first ?? sets.first
        self.sets = work.isEmpty ? nil : work.count
        self.reps = primary?.reps
        self.loadLbs = primary?.loadLbs
        self.holdSeconds = primary?.holdSeconds
        let wu = sets.filter(\.isWarmup)
        if let firstWU = wu.first {
            warmupReps = firstWU.reps
            warmupHoldSeconds = firstWU.holdSeconds
            warmupLoadLbs = firstWU.loadLbs
        } else {
            warmupReps = nil
            warmupHoldSeconds = nil
            warmupLoadLbs = nil
        }
    }

    private func legacyAsSets() -> [ResistanceSet] {
        var result: [ResistanceSet] = []
        if warmupReps != nil || warmupHoldSeconds != nil || warmupLoadLbs != nil {
            result.append(
                ResistanceSet(
                    reps: warmupReps,
                    loadLbs: warmupLoadLbs,
                    holdSeconds: warmupHoldSeconds,
                    isWarmup: true
                )
            )
        }
        if sessionType == .isometrics {
            if reps != nil || holdSeconds != nil || loadLbs != nil {
                result.append(
                    ResistanceSet(reps: reps, loadLbs: loadLbs, holdSeconds: holdSeconds, isWarmup: false)
                )
            }
        } else if let setCount = sets, setCount > 0, reps != nil || loadLbs != nil {
            // Expand uniform sets into individual rows
            for _ in 0..<setCount {
                result.append(
                    ResistanceSet(reps: reps, loadLbs: loadLbs, holdSeconds: nil, isWarmup: false)
                )
            }
        } else if reps != nil || loadLbs != nil {
            result.append(
                ResistanceSet(reps: reps, loadLbs: loadLbs, holdSeconds: holdSeconds, isWarmup: false)
            )
        }
        return result
    }

    var hasResistanceLog: Bool {
        !resistanceSets().isEmpty
            || loadLbs != nil || sets != nil || reps != nil || holdSeconds != nil
            || warmupLoadLbs != nil || warmupReps != nil || warmupHoldSeconds != nil
    }

    /// Work-set volume for Progress: Σ reps × loadLbs via `resistanceSets()`.
    /// Load-only rows with no reps stay nil so they are not labeled as volume.
    var chartVolume: Double? {
        ResistanceMath.chartVolume(resistanceSets())
    }

    /// Max work-set load (lb). Used by the session editor last-session row.
    var chartMaxLoad: Double? {
        ResistanceMath.chartMaxLoad(work: resistanceSets())
    }

    /// Exercise name only (drops the auto-filled set list).
    var displayTitle: String {
        SessionSummary.displayTitle(whatIDid: whatIDid)
    }

    /// Compact resistance line for cards — not every L/R row.
    var resistanceSummary: String? {
        SessionSummary.compactResistance(resistanceSets())
    }

    static func formatLoad(_ lbs: Double) -> String {
        LoadCopy.formatted(lbs)
    }

    var hasLoggedPainAfter: Bool {
        PainScore.isLogged(painAfter)
    }

    var loggedPainAfter: Int? {
        PainScore.optional(painAfter)
    }

    var displayPainAfter: String {
        PainScore.display(painAfter)
    }
}
