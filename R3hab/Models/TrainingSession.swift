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
    /// Structured resistance (optional).
    var sets: Int?
    var reps: Int?
    /// Machine load in pounds. Stored under original column name `loadKg` for existing installs.
    @Attribute(originalName: "loadKg")
    var loadLbs: Double?
    /// Hold duration in seconds (isometrics). Nil for pure HSR working sets.
    var holdSeconds: Int?
    /// Optional isometric warm-up before HSR (reps = holds, time, load).
    var warmupReps: Int?
    var warmupHoldSeconds: Int?
    var warmupLoadLbs: Double?
    /// Which Progress chart series this load plots on (`knee` / `lowerBack`). Nil + load → treated as knee for legacy rows.
    var loadRegionRaw: String?
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
        self.loadRegionRaw = loadRegion?.rawValue
        self.response24hRaw = Response24h.pending.rawValue
        self.decisionRaw = nil
        self.notes = ""
        self.snoozedUntil = nil
        self.snoozeUsed = false
        self.resolvedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// True when this session carries structured load suitable for resistance charts.
    var hasResistanceLog: Bool {
        loadLbs != nil || sets != nil || reps != nil || holdSeconds != nil
            || warmupLoadLbs != nil || warmupReps != nil || warmupHoldSeconds != nil
    }

    /// Prefer working-set load for Progress; fall back to warm-up load if only warm-up logged.
    var chartLoadLbs: Double? {
        if let loadLbs { return loadLbs }
        return warmupLoadLbs
    }

    var resistanceSummary: String? {
        guard hasResistanceLog else { return nil }
        var parts: [String] = []
        if let wu = Self.formatIsoBlock(reps: warmupReps, holdSeconds: warmupHoldSeconds, loadLbs: warmupLoadLbs) {
            parts.append("WU \(wu)")
        }
        if sessionType == .isometrics {
            if let block = Self.formatIsoBlock(reps: reps, holdSeconds: holdSeconds, loadLbs: loadLbs) {
                parts.append(block)
            }
        } else {
            var work: [String] = []
            if let sets, let reps {
                work.append("\(sets)×\(reps)")
            } else if let sets {
                work.append("\(sets) sets")
            } else if let reps {
                work.append("\(reps) reps")
            }
            if let loadLbs {
                work.append("@ \(Self.formatLoad(loadLbs)) lb")
            }
            if !work.isEmpty {
                parts.append(work.joined(separator: " "))
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func formatIsoBlock(reps: Int?, holdSeconds: Int?, loadLbs: Double?) -> String? {
        var bits: [String] = []
        if let reps, let holdSeconds {
            bits.append("\(reps)×\(holdSeconds)s")
        } else if let reps {
            bits.append("\(reps) holds")
        } else if let holdSeconds {
            bits.append("\(holdSeconds)s")
        }
        if let loadLbs {
            bits.append("@ \(Self.formatLoad(loadLbs)) lb")
        }
        return bits.isEmpty ? nil : bits.joined(separator: " ")
    }

    static func formatLoad(_ lbs: Double) -> String {
        if lbs.rounded() == lbs {
            return String(Int(lbs))
        }
        return String(format: "%g", lbs)
    }
}
