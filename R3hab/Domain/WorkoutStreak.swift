import Foundation

/// Hard-session chain for Today.
///
/// Moment used for every gap is `createdAt` (same clock `SessionSpacing` uses),
/// not the calendar `date` field. A hard session continues the chain when it
/// lands within 48 hours of the previous hard session’s `createdAt`.
/// A gap **greater than** 48 hours starts a new chain.
///
/// Same-day doubles count as two links if both are hard — two isometrics
/// three hours apart are two votes, not one.
///
/// `.other` is ignored. Current streak stays live only while `now` is still
/// inside 48 hours of the latest hard session; after that the live count is 0
/// and `lastChain` remembers what just broke.
enum WorkoutStreak {
    static let approachingHours: Double = 36

    enum MissState: Equatable, Sendable {
        /// Never trained, or last hard session is still inside the 48h window.
        case none
        /// Last hard session is 36–48h ago — window closing, chain still live.
        case approaching
        /// One 48h window missed (48–96h). Calm “don’t miss twice.”
        case oneMiss
        /// Second window missed (>96h). Stronger nudge.
        case twoMiss
    }

    struct Snapshot: Equatable, Sendable {
        var current: Int
        var lastChain: Int
        var best: Int
        var hoursSinceLastHard: Double?
        var lastHardAt: Date?
        var miss: MissState
    }

    static func evaluate(
        sessions: [TrainingSessionSnapshot],
        now: Date
    ) -> Snapshot {
        let hard = sessions
            .filter { SessionSpacing.isHard($0.sessionType) }
            .sorted { $0.createdAt < $1.createdAt }

        guard let latest = hard.last else {
            return Snapshot(
                current: 0,
                lastChain: 0,
                best: 0,
                hoursSinceLastHard: nil,
                lastHardAt: nil,
                miss: .none
            )
        }

        var chains: [Int] = []
        var run = 1
        for index in 1..<hard.count {
            let gap = hard[index].createdAt.timeIntervalSince(hard[index - 1].createdAt)
            if gap <= SessionSpacing.hardGap {
                run += 1
            } else {
                chains.append(run)
                run = 1
            }
        }
        chains.append(run)

        let lastChain = chains.last ?? 0
        let best = chains.max() ?? 0
        let hours = now.timeIntervalSince(latest.createdAt) / 3600.0
        let isLive = hours <= SessionSpacing.hardGapHours

        return Snapshot(
            current: isLive ? lastChain : 0,
            lastChain: lastChain,
            best: best,
            hoursSinceLastHard: hours,
            lastHardAt: latest.createdAt,
            miss: missState(hoursSinceLastHard: hours)
        )
    }

    static func missState(hoursSinceLastHard: Double) -> MissState {
        if hoursSinceLastHard <= approachingHours {
            return .none
        }
        if hoursSinceLastHard <= SessionSpacing.hardGapHours {
            return .approaching
        }
        if hoursSinceLastHard <= SessionSpacing.hardGapHours * 2 {
            return .oneMiss
        }
        return .twoMiss
    }

    static func copy(for miss: MissState, lastChain: Int) -> (title: String, body: String)? {
        switch miss {
        case .none:
            return nil
        case .approaching:
            return (
                "Window closing",
                "A hard session in the next hours keeps the chain. One seated extension still counts."
            )
        case .oneMiss:
            let chain = lastChain > 0 ? " Last chain: \(sessionWord(lastChain))." : ""
            return (
                "One miss is alright",
                "Don’t miss twice — don’t break the chain.\(chain) Inspired by Atomic Habits."
            )
        case .twoMiss:
            return (
                "Start the chain again",
                "Two windows slipped. One hard session today is the reset — process over a perfect record."
            )
        }
    }

    static func sessionWord(_ count: Int) -> String {
        count == 1 ? "1 session" : "\(count) sessions"
    }
}
