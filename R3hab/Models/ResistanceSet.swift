import Foundation

enum KneeSide: String, Codable, CaseIterable, Identifiable, Sendable {
    case left
    case right

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .left: return "L"
        case .right: return "R"
        }
    }

    var title: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        }
    }
}

enum LoadCopy {
    static let unit = "lbs"

    static func labeled(_ lbs: Double) -> String {
        "\(TrainingSession.formatLoad(lbs)) \(unit)"
    }
}

/// One working or warm-up set inside a training session.
struct ResistanceSet: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    /// Reps (or number of holds for isometrics).
    var reps: Int?
    /// Load in pounds (stored as lb; UI shows lbs).
    var loadLbs: Double?
    /// Hold seconds (isometrics / warm-up holds).
    var holdSeconds: Int?
    var isWarmup: Bool
    /// Left or right knee. Nil on legacy rows and warm-ups.
    var side: KneeSide?

    init(
        id: UUID = UUID(),
        reps: Int? = nil,
        loadLbs: Double? = nil,
        holdSeconds: Int? = nil,
        isWarmup: Bool = false,
        side: KneeSide? = nil
    ) {
        self.id = id
        self.reps = reps
        self.loadLbs = loadLbs
        self.holdSeconds = holdSeconds
        self.isWarmup = isWarmup
        self.side = side
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
        if let side {
            parts.append(side.shortLabel)
        }
        if let loadLbs {
            parts.append("@ \(LoadCopy.labeled(loadLbs))")
        }
        return parts.joined(separator: " ")
    }
}

/// How working sets are logged: one load for both knees, or a distinct load per side.
enum SetLaterality: String, CaseIterable, Identifiable, Sendable {
    case bilateral
    case unilateral

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bilateral: return "Both legs"
        case .unilateral: return "Each leg"
        }
    }
}

/// One conceptual working set, backed by left + right `ResistanceSet` rows.
struct WorkSetPair: Equatable, Identifiable, Sendable {
    var left: ResistanceSet
    var right: ResistanceSet?

    var id: UUID { left.id }

    var reps: Int? { left.reps }
    var holdSeconds: Int? { left.holdSeconds }
    var leftLoad: Double? { left.loadLbs }
    var rightLoad: Double? { right?.loadLbs ?? left.loadLbs }

    var loadsMatch: Bool {
        guard let right else { return true }
        switch (left.loadLbs, right.loadLbs) {
        case (nil, nil): return true
        case let (l?, r?): return l == r
        default: return false
        }
    }
}

/// Compact session copy for cards, charts, and auto-filled “what I did”.
enum SessionSummary {
    static func displayTitle(whatIDid: String) -> String {
        let trimmed = whatIDid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Session" }
        let head = trimmed.split(separator: "·", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let head, !head.isEmpty { return head }
        return trimmed
    }

    static func groupWorkSets(_ sets: [ResistanceSet]) -> [WorkSetPair] {
        var result: [WorkSetPair] = []
        var index = 0
        while index < sets.count {
            let current = sets[index]
            if current.side == nil {
                result.append(WorkSetPair(left: current, right: nil))
                index += 1
                continue
            }
            if index + 1 < sets.count {
                let next = sets[index + 1]
                if let sideA = current.side, let sideB = next.side, sideA != sideB {
                    let left = sideA == .left ? current : next
                    let right = sideA == .right ? current : next
                    result.append(WorkSetPair(left: left, right: right))
                    index += 2
                    continue
                }
            }
            result.append(WorkSetPair(left: current, right: nil))
            index += 1
        }
        return result
    }

    static func inferredLaterality(workSets: [ResistanceSet]) -> SetLaterality {
        let pairs = groupWorkSets(workSets.filter { !$0.isWarmup })
        if pairs.contains(where: { $0.right != nil && !$0.loadsMatch }) {
            return .unilateral
        }
        return .bilateral
    }

    static func makePair(
        reps: Int,
        loadLbs: Double?,
        holdSeconds: Int?,
        isWarmup: Bool,
        rightLoadLbs: Double? = nil
    ) -> [ResistanceSet] {
        [
            ResistanceSet(
                reps: reps,
                loadLbs: loadLbs,
                holdSeconds: holdSeconds,
                isWarmup: isWarmup,
                side: .left
            ),
            ResistanceSet(
                reps: reps,
                loadLbs: rightLoadLbs ?? loadLbs,
                holdSeconds: holdSeconds,
                isWarmup: isWarmup,
                side: .right
            )
        ]
    }

    /// Rebuild L/R rows from pairs when switching Both legs ↔ Each leg.
    static func applyLaterality(_ laterality: SetLaterality, to sets: [ResistanceSet]) -> [ResistanceSet] {
        groupWorkSets(sets).flatMap { pair -> [ResistanceSet] in
            let reps = pair.reps
            let hold = pair.holdSeconds
            let leftLoad = pair.leftLoad
            let rightLoad: Double?
            switch laterality {
            case .bilateral:
                rightLoad = leftLoad ?? pair.rightLoad
            case .unilateral:
                rightLoad = pair.rightLoad ?? leftLoad
            }
            return makePair(
                reps: reps ?? 8,
                loadLbs: laterality == .bilateral ? (leftLoad ?? rightLoad) : leftLoad,
                holdSeconds: hold,
                isWarmup: pair.left.isWarmup,
                rightLoadLbs: laterality == .bilateral ? (leftLoad ?? rightLoad) : rightLoad
            )
        }
    }

    /// Short resistance line, e.g. `3×8 @ 15 lbs both · WU 2×30s @ 15 lbs`.
    static func compactResistance(_ sets: [ResistanceSet]) -> String? {
        let warmup = sets.filter(\.isWarmup)
        let work = sets.filter { !$0.isWarmup }
        var parts: [String] = []
        if let workText = compactPairs(groupWorkSets(work), warmup: false) {
            parts.append(workText)
        }
        if let warmupText = compactPairs(groupWorkSets(warmup), warmup: true) {
            parts.append(warmupText)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private struct ClusterSignature: Hashable {
        var reps: Int?
        var hold: Int?
        var leftLoad: Double?
        var rightLoad: Double?
        var loadsMatch: Bool
        var paired: Bool
    }

    private static func compactPairs(_ pairs: [WorkSetPair], warmup: Bool) -> String? {
        guard !pairs.isEmpty else { return nil }
        var clusters: [(ClusterSignature, Int)] = []
        for pair in pairs {
            let signature = ClusterSignature(
                reps: pair.reps,
                hold: pair.holdSeconds,
                leftLoad: pair.leftLoad,
                rightLoad: pair.rightLoad,
                loadsMatch: pair.loadsMatch,
                paired: pair.right != nil || pair.left.side == nil
            )
            if let last = clusters.last, last.0 == signature {
                clusters[clusters.count - 1].1 += 1
            } else {
                clusters.append((signature, 1))
            }
        }
        let body = clusters
            .map { formatCluster($0.0, count: $0.1, warmup: warmup) }
            .joined(separator: ", ")
        return warmup ? "WU \(body)" : body
    }

    private static func formatCluster(_ signature: ClusterSignature, count: Int, warmup: Bool) -> String {
        let dose: String
        if let hold = signature.hold, hold > 0 {
            if let reps = signature.reps {
                dose = "\(reps)×\(hold)s"
            } else {
                dose = "\(hold)s"
            }
        } else if let reps = signature.reps {
            dose = "\(reps)"
        } else {
            dose = ""
        }

        let counted: String
        if dose.isEmpty {
            counted = count == 1 ? "1 set" : "\(count) sets"
        } else if let hold = signature.hold, hold > 0 {
            counted = count > 1 ? "\(count)× \(dose)" : dose
        } else {
            counted = count > 1 ? "\(count)×\(dose)" : dose
        }

        let load: String
        if signature.loadsMatch {
            guard let lbs = signature.leftLoad else {
                load = ""
                return [counted, load].filter { !$0.isEmpty }.joined(separator: " ")
            }
            let bothSuffix = (!warmup && signature.paired) ? " both" : ""
            load = "@ \(LoadCopy.labeled(lbs))\(bothSuffix)"
        } else {
            let left = signature.leftLoad.map(LoadCopy.labeled) ?? "—"
            let right = signature.rightLoad.map(LoadCopy.labeled) ?? "—"
            load = "L @ \(left) / R @ \(right)"
        }
        return [counted, load].filter { !$0.isEmpty }.joined(separator: " ")
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
