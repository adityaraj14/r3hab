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
    /// Which Progress chart series this load plots on (`knee` / `lowerBack`).
    var loadRegionRaw: String?
    /// Rehab track this session belongs to (`knee` / `lowerBack`). Defaults from load region.
    var trackRaw: String?
    var response24hRaw: String
    var decisionRaw: String?
    var notes: String
    var snoozedUntil: Date?
    var snoozeUsed: Bool
    var resolvedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var phase: RehabPhase {
        get { RehabPhase(rawValue: phaseRaw) ?? .aFlareDeLoad }
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

    var loadRegion: LoadRegion? {
        get {
            guard let loadRegionRaw else { return nil }
            return LoadRegion(rawValue: loadRegionRaw)
        }
        set { loadRegionRaw = newValue?.rawValue }
    }

    var track: RehabTrackID {
        get {
            if let trackRaw, let t = RehabTrackID(rawValue: trackRaw) { return t }
            if let loadRegion {
                return loadRegion == .lowerBack ? .lowerBack : .knee
            }
            return .knee
        }
        set {
            trackRaw = newValue.rawValue
            loadRegionRaw = newValue.loadRegion.rawValue
        }
    }

    /// Region used for Progress load series. Legacy rows with load but no region map to knee.
    var effectiveLoadRegion: LoadRegion? {
        if let loadRegion { return loadRegion }
        if hasResistanceLog { return .knee }
        return nil
    }

    init(
        id: UUID = UUID(),
        date: Date,
        phase: RehabPhase,
        sessionType: SessionType,
        whatIDid: String,
        painDuring: Int,
        painAfter: Int,
        sets: Int? = nil,
        reps: Int? = nil,
        loadLbs: Double? = nil,
        holdSeconds: Int? = nil,
        warmupReps: Int? = nil,
        warmupHoldSeconds: Int? = nil,
        warmupLoadLbs: Double? = nil,
        loadRegion: LoadRegion? = nil,
        track: RehabTrackID? = nil,
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
        self.loadRegionRaw = loadRegion?.rawValue ?? track?.loadRegion.rawValue
        self.trackRaw = track?.rawValue
            ?? (loadRegion == .lowerBack ? RehabTrackID.lowerBack.rawValue : RehabTrackID.knee.rawValue)
        self.response24hRaw = Response24h.pending.rawValue
        self.decisionRaw = nil
        self.notes = ""
        self.snoozedUntil = nil
        self.snoozeUsed = false
        self.resolvedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
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

    /// Volume (Σ reps × lb) for Progress charts.
    var chartVolume: Double? {
        let all = resistanceSets()
        return ResistanceMath.chartVolume(work: all)
    }

    /// Max load (lb) for legend context.
    var chartMaxLoad: Double? {
        ResistanceMath.chartMaxLoad(work: resistanceSets())
    }

    /// Backward-compatible single load for older call sites.
    var chartLoadLbs: Double? {
        chartMaxLoad
    }

    var resistanceSummary: String? {
        let all = resistanceSets()
        guard !all.isEmpty else { return nil }
        let wu = all.filter(\.isWarmup)
        let work = all.filter { !$0.isWarmup }
        var parts: [String] = []
        if !wu.isEmpty {
            parts.append("WU " + wu.map(\.summary).joined(separator: ", "))
        }
        if !work.isEmpty {
            parts.append(work.map(\.summary).joined(separator: ", "))
        }
        if let vol = chartVolume, vol > 0 {
            parts.append("vol \(TrainingSession.formatLoad(vol))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func formatLoad(_ lbs: Double) -> String {
        if lbs.rounded() == lbs {
            return String(Int(lbs))
        }
        return String(format: "%g", lbs)
    }
}
