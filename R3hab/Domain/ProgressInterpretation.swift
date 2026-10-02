import Foundation

enum ProgressWindowTone: Equatable, Sendable {
    case positive
    case caution
    case partial
    case insufficient
    case steady
}

struct ProgressWindowReadout: Equatable, Sendable {
    var tone: ProgressWindowTone
    var headline: String
    var detail: String?
}

enum ProgressVolumeTrend: Equatable, Sendable {
    case up
    case down
    case flat
}

enum ProgressPainTrend: Equatable, Sendable {
    case up
    case down
    case flat
}

/// Plain-English read of pain vs volume in the selected Progress window.
enum ProgressInterpretation {
    static let painFlatMax = 0.75
    static let painRiseMin = 1.0
    static let volumeChangeRatio = 0.10

    static func classify(points: [DayExplorePoint]) -> ProgressWindowReadout {
        let pain = painTrend(in: points)
        let volume = volumeTrend(in: points)

        switch (volume, pain) {
        case (nil, nil):
            return ProgressWindowReadout(
                tone: .insufficient,
                headline: "This window does not have enough days.",
                detail: nil
            )
        case (.up?, .flat?), (.up?, .down?):
            let detail = pain == .down
                ? "The load is higher and the pain decreases."
                : "The load is higher and the pain stays the same."
            return ProgressWindowReadout(
                tone: .positive,
                headline: "This result is good.",
                detail: detail
            )
        case (.up?, .up?):
            return ProgressWindowReadout(
                tone: .caution,
                headline: "Examine this result.",
                detail: "The load is higher and the pain increases with it."
            )
        case (.flat?, .up?), (.down?, .up?):
            return ProgressWindowReadout(
                tone: .caution,
                headline: "Examine this result.",
                detail: "The pain increases and the sessions are fewer."
            )
        case (.flat?, .flat?), (.flat?, .down?), (.down?, .flat?), (.down?, .down?):
            let quieter = volume == .down
            return ProgressWindowReadout(
                tone: .steady,
                headline: quieter ? "The load is lower." : "This window is stable.",
                detail: quieter
                    ? "The load decreases and the pain stays low."
                    : "The pain and the load stay the same."
            )
        case (nil, .down?):
            return ProgressWindowReadout(
                tone: .partial,
                headline: "The pain decreases.",
                detail: "Record more sessions to see the load."
            )
        case (nil, .flat?):
            return ProgressWindowReadout(
                tone: .partial,
                headline: "The pain stays the same.",
                detail: "The session volume shows the rest of the result."
            )
        case (nil, .up?):
            return ProgressWindowReadout(
                tone: .partial,
                headline: "The pain increases.",
                detail: "Examine this pain. Record the session volume."
            )
        case (.up?, nil):
            return ProgressWindowReadout(
                tone: .partial,
                headline: "The load is higher.",
                detail: "The morning pain shows if the load is acceptable."
            )
        case (.flat?, nil), (.down?, nil):
            return ProgressWindowReadout(
                tone: .partial,
                headline: "The session volume is low in this window.",
                detail: "Record the pain to complete this window."
            )
        }
    }

    static func painTrend(in points: [DayExplorePoint]) -> ProgressPainTrend? {
        let samples = points.compactMap(\.pain)
        guard samples.count >= 2 else { return nil }
        let mid = points.count / 2
        let earlyHalf = points.prefix(mid).compactMap(\.pain)
        let lateHalf = points.suffix(points.count - mid).compactMap(\.pain)
        let early: Double
        let late: Double
        if let earlyMean = mean(earlyHalf), let lateMean = mean(lateHalf) {
            early = earlyMean
            late = lateMean
        } else {
            early = samples[0]
            late = samples[samples.count - 1]
        }
        let delta = late - early
        if delta <= -painFlatMax { return .down }
        if delta >= painRiseMin { return .up }
        return .flat
    }

    static func volumeTrend(in points: [DayExplorePoint]) -> ProgressVolumeTrend? {
        let sessionDays = points.filter { $0.volume != nil }.count
        guard sessionDays >= 2 else { return nil }
        let mid = max(points.count / 2, 1)
        let early = points.prefix(mid).reduce(0.0) { $0 + ($1.volume ?? 0) }
        let late = points.suffix(points.count - mid).reduce(0.0) { $0 + ($1.volume ?? 0) }
        if early == 0 && late == 0 { return nil }
        if early == 0 { return late > 0 ? .up : .flat }
        let ratio = late / early
        if ratio >= 1 + volumeChangeRatio { return .up }
        if ratio <= 1 - volumeChangeRatio { return .down }
        return .flat
    }

    private static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
