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
    /// Hold duration in seconds (isometrics). Nil for HSR (fixed 3s up / 3s down tempo).
    var holdSeconds: Int?
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
    }

    var resistanceSummary: String? {
        guard hasResistanceLog else { return nil }
        var parts: [String] = []
        if sessionType == .isometrics {
            // e.g. 4×30s @ 15 lb
            if let reps, let holdSeconds {
                parts.append("\(reps)×\(holdSeconds)s")
            } else if let reps {
                parts.append("\(reps) holds")
            } else if let holdSeconds {
                parts.append("\(holdSeconds)s")
            }
            if let loadLbs {
                parts.append("@ \(Self.formatLoad(loadLbs)) lb")
            }
        } else {
            if let sets, let reps {
                parts.append("\(sets)×\(reps)")
            } else if let sets {
                parts.append("\(sets) sets")
            } else if let reps {
                parts.append("\(reps) reps")
            }
            if let loadLbs {
                parts.append("@ \(Self.formatLoad(loadLbs)) lb")
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    static func formatLoad(_ lbs: Double) -> String {
        if lbs.rounded() == lbs {
            return String(Int(lbs))
        }
        return String(format: "%g", lbs)
    }
}
