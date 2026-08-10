import Foundation

/// One working or warm-up set inside a training session.
struct ResistanceSet: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    /// Reps (or number of holds for isometrics).
    var reps: Int?
    /// Load in pounds.
    var loadLbs: Double?
    /// Hold seconds (isometrics / warm-up holds).
    var holdSeconds: Int?
    var isWarmup: Bool

    init(
        id: UUID = UUID(),
        reps: Int? = nil,
        loadLbs: Double? = nil,
        holdSeconds: Int? = nil,
        isWarmup: Bool = false
    ) {
        self.id = id
        self.reps = reps
        self.loadLbs = loadLbs
        self.holdSeconds = holdSeconds
        self.isWarmup = isWarmup
    }

    /// Volume contribution: reps × load (hold sets still count via reps × load).
    var volume: Double {
        let r = Double(reps ?? 0)
        let l = loadLbs ?? 0
        return r * l
    }

    var summary: String {
        var parts: [String] = []
        if isWarmup { parts.append("WU") }
        if let holdSeconds, holdSeconds > 0 {
            if let reps {
                parts.append("\(reps)×\(holdSeconds)s")
            } else {
                parts.append("\(holdSeconds)s")
            }
        } else if let reps {
            parts.append("\(reps)r")
        }
        if let loadLbs {
            parts.append("@ \(TrainingSession.formatLoad(loadLbs)) lb")
        }
        return parts.joined(separator: " ")
    }
}

enum ResistanceMath {
    /// Total volume across non-empty sets (reps × lb).
    static func totalVolume(_ sets: [ResistanceSet]) -> Double {
        sets.reduce(0) { $0 + $1.volume }
    }

    /// Max load among sets that have a load value.
    static func maxLoad(_ sets: [ResistanceSet]) -> Double? {
        let loads = sets.compactMap(\.loadLbs)
        return loads.max()
    }

    /// Prefer work volume; if only warm-up, use warm-up volume.
    static func chartVolume(work: [ResistanceSet], warmup: [ResistanceSet] = []) -> Double? {
        let workVol = totalVolume(work.filter { !$0.isWarmup })
        if workVol > 0 { return workVol }
        let wu = totalVolume(warmup.isEmpty ? work.filter(\.isWarmup) : warmup)
        return wu > 0 ? wu : nil
    }

    static func chartMaxLoad(work: [ResistanceSet], warmup: [ResistanceSet] = []) -> Double? {
        if let m = maxLoad(work.filter { !$0.isWarmup }) { return m }
        return maxLoad(warmup.isEmpty ? work.filter(\.isWarmup) : warmup)
    }
}
