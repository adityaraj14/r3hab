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
        "\(formatted(lbs)) \(unit)"
    }

    static func formatted(_ lbs: Double) -> String {
        if lbs.rounded() == lbs {
            return String(Int(lbs))
        }
        return String(format: "%g", lbs)
    }
}

enum VolumeCopy {
    static let unit = "lb·reps"

    static func labeled(_ value: Double) -> String {
        "\(formatted(value)) \(unit)"
    }

    static func formatted(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        if value.rounded() == value {
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
        } else {
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 0
        }
        return formatter.string(from: NSNumber(value: value)) ?? LoadCopy.formatted(value)
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
    /// 0–10 when logged on this row. Nil on legacy JSON and warm-ups.
    var painDuring: Int?

    init(
        id: UUID = UUID(),
        reps: Int? = nil,
        loadLbs: Double? = nil,
        holdSeconds: Int? = nil,
        isWarmup: Bool = false,
        side: KneeSide? = nil,
        painDuring: Int? = nil
    ) {
        self.id = id
        self.reps = reps
        self.loadLbs = loadLbs
        self.holdSeconds = holdSeconds
        self.isWarmup = isWarmup
        self.side = side
        self.painDuring = painDuring
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

/// Structured History card rows. Reuses `WorkSetPair`; not a second set model.
struct HistoryResistanceList: Equatable, Sendable {
    var workCount: Int
    var warmupCount: Int
    var rows: [HistoryResistanceRow]
    var hiddenWorkCount: Int

    var header: String? {
        var parts: [String] = []
        if workCount > 0 {
            parts.append(workCount == 1 ? "1 work" : "\(workCount) work")
        }
        if warmupCount > 0 {
            parts.append(warmupCount == 1 ? "1 warm-up" : "\(warmupCount) warm-ups")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var spokenSummary: String {
        let head = header.map { $0.replacingOccurrences(of: " · ", with: ", ") }
        let body = rows.map(\.spoken)
        return ([head].compactMap { $0 } + body).joined(separator: ". ")
    }
}

struct HistoryResistanceRow: Equatable, Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        case warmup
        case work(Int)
        case overflow(Int)

        var id: String {
            switch self {
            case .warmup: return "wu"
            case .work(let n): return "work-\(n)"
            case .overflow(let n): return "more-\(n)"
            }
        }

        var label: String {
            switch self {
            case .warmup: return "WU"
            case .work(let n): return "\(n)"
            case .overflow(let n): return "+\(n)"
            }
        }
    }

    var id: String
    var kind: Kind
    var dose: String
    var load: String
    var laterality: String?
    var spoken: String

    var isWarmup: Bool {
        if case .warmup = kind { return true }
        return false
    }

    var isOverflow: Bool {
        if case .overflow = kind { return true }
        return false
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

    /// Auto-filled “what I did” looks like `Seated extension · 4×30s @ 35 lbs`.
    static func looksStructuredWhatIDid(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("wu")
            || lower.contains("lb")
            || lower.contains("lbs")
            || lower.contains("×")
            || lower.contains("x")
            || lower.contains("set")
            || lower.contains("both")
    }

    /// One-line logger context, e.g. `Last: 4×30s @ 35 lbs · pain 2`.
    static func lastSessionLine(
        whatIDid: String,
        sets: [ResistanceSet],
        painDuring: Int
    ) -> String {
        let work = sets.filter { !$0.isWarmup }
        let dose = compactResistance(work)?.replacingOccurrences(of: " both", with: "")
        let body: String
        if let dose, !dose.isEmpty {
            body = dose
        } else {
            body = displayTitle(whatIDid: whatIDid)
        }
        if PainScore.isLogged(painDuring) {
            return "Last: \(body) · pain \(painDuring)"
        }
        return "Last: \(body)"
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

    /// Numbered History card rows. Warm-ups first, then work sets.
    static func historyResistanceList(
        _ sets: [ResistanceSet],
        maxWorkVisible: Int = 4
    ) -> HistoryResistanceList? {
        let warmupPairs = groupWorkSets(sets.filter(\.isWarmup))
        let workPairs = groupWorkSets(sets.filter { !$0.isWarmup })
        guard !warmupPairs.isEmpty || !workPairs.isEmpty else { return nil }

        var rows: [HistoryResistanceRow] = []
        for pair in warmupPairs {
            rows.append(historyRow(pair: pair, kind: .warmup))
        }

        let showOverflow = workPairs.count > 5
        let visibleWork = showOverflow ? Array(workPairs.prefix(maxWorkVisible)) : workPairs
        for (index, pair) in visibleWork.enumerated() {
            rows.append(historyRow(pair: pair, kind: .work(index + 1)))
        }
        let hiddenWorkCount = showOverflow ? workPairs.count - visibleWork.count : 0
        if hiddenWorkCount > 0 {
            rows.append(
                HistoryResistanceRow(
                    id: "more-\(hiddenWorkCount)",
                    kind: .overflow(hiddenWorkCount),
                    dose: "",
                    load: "",
                    laterality: nil,
                    spoken: hiddenWorkCount == 1
                        ? "1 more work set"
                        : "\(hiddenWorkCount) more work sets"
                )
            )
        }

        return HistoryResistanceList(
            workCount: workPairs.count,
            warmupCount: warmupPairs.count,
            rows: rows,
            hiddenWorkCount: hiddenWorkCount
        )
    }

    private static func historyRow(pair: WorkSetPair, kind: HistoryResistanceRow.Kind) -> HistoryResistanceRow {
        let dose = historyDose(reps: pair.reps, holdSeconds: pair.holdSeconds)
        let load = historyLoad(pair)
        let laterality = historyLaterality(pair)
        return HistoryResistanceRow(
            id: kind.id + "-" + pair.id.uuidString,
            kind: kind,
            dose: dose,
            load: load,
            laterality: laterality,
            spoken: historySpoken(
                kind: kind,
                reps: pair.reps,
                holdSeconds: pair.holdSeconds,
                pair: pair,
                laterality: laterality
            )
        )
    }

    static func historyDose(reps: Int?, holdSeconds: Int?) -> String {
        if let hold = holdSeconds, hold > 0 {
            if let reps, reps > 1 {
                return "\(reps)×\(hold)s"
            }
            return "\(hold)s"
        }
        if let reps {
            return "\(reps)"
        }
        return ""
    }

    private static func historyLoad(_ pair: WorkSetPair) -> String {
        if pair.loadsMatch {
            guard let lbs = pair.leftLoad else { return "" }
            return "@ \(LoadCopy.formatted(lbs))"
        }
        let left = pair.leftLoad.map(LoadCopy.formatted) ?? "—"
        let right = pair.rightLoad.map(LoadCopy.formatted) ?? "—"
        return "@ L \(left) / R \(right)"
    }

    private static func historyLaterality(_ pair: WorkSetPair) -> String? {
        if !pair.loadsMatch { return nil }
        if pair.right != nil || pair.left.side == nil { return "both" }
        return pair.left.side?.shortLabel
    }

    private static func historySpoken(
        kind: HistoryResistanceRow.Kind,
        reps: Int?,
        holdSeconds: Int?,
        pair: WorkSetPair,
        laterality: String?
    ) -> String {
        let label: String
        switch kind {
        case .warmup:
            label = "Warm-up"
        case .work(let number):
            label = "Set \(number)"
        case .overflow(let count):
            return count == 1 ? "1 more work set" : "\(count) more work sets"
        }

        let effort: String
        if let hold = holdSeconds, hold > 0 {
            if let reps, reps > 1 {
                effort = "\(reps) holds of \(hold) seconds"
            } else {
                effort = "\(hold) seconds"
            }
        } else if let reps {
            effort = reps == 1 ? "1 rep" : "\(reps) reps"
        } else {
            effort = "set"
        }

        let load: String
        if pair.loadsMatch {
            if let lbs = pair.leftLoad {
                load = "at \(LoadCopy.formatted(lbs))"
            } else {
                load = ""
            }
        } else {
            let left = pair.leftLoad.map(LoadCopy.formatted) ?? "none"
            let right = pair.rightLoad.map(LoadCopy.formatted) ?? "none"
            load = "at left \(left), right \(right)"
        }

        let side = laterality.map { $0 == "both" ? "both" : $0 } ?? ""
        return [label, effort, load, side].filter { !$0.isEmpty }.joined(separator: ", ")
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

    /// Work-set volume only (Σ reps × lb). Warm-ups and hold seconds are ignored.
    static func chartVolume(_ sets: [ResistanceSet]) -> Double? {
        let workVol = totalVolume(sets.filter { !$0.isWarmup })
        return workVol > 0 ? workVol : nil
    }

    static func chartMaxLoad(work: [ResistanceSet], warmup: [ResistanceSet] = []) -> Double? {
        if let m = maxLoad(work.filter { !$0.isWarmup }) { return m }
        return maxLoad(warmup.isEmpty ? work.filter(\.isWarmup) : warmup)
    }
}
