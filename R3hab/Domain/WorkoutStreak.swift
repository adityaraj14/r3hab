import Foundation

/// Hard-session chain for Today.
///
/// Every gap is measured in **local calendar days** on the session’s `date`
/// (the day the user trained), never in raw hours. A hard session on day D keeps
/// the chain if the next one lands on or before day D + `SessionSpacing.hardCadenceDays`
/// — the user gets the entire due day, so 7 AM Monday then 5 PM Wednesday is
/// one unbroken chain. A gap of more calendar days than that starts a new chain.
///
/// Same-day doubles count as two links if both are hard — two isometrics
/// three hours apart are two votes, not one.
///
/// `.other` is ignored. Current streak stays live through the end of the due
/// day; from the next morning the live count is 0 and `lastChain` remembers
/// what just broke.
enum WorkoutStreak {
    enum MissState: Equatable, Sendable {
        /// Never trained, or the due day has not arrived yet.
        case none
        /// Today is the due day and nothing hard is logged yet — chain still live.
        case approaching
        /// Due day ended with no hard session (the next two days). Calm “don’t miss twice.”
        case oneMiss
        /// Second due day also missed. Stronger nudge.
        case twoMiss
    }

    struct Snapshot: Equatable, Sendable {
        var current: Int
        var lastChain: Int
        var best: Int
        /// Whole calendar days from the last hard session’s day to today.
        var daysSinceLastHard: Int?
        /// Start of the last hard session’s day.
        var lastHardDay: Date?
        var miss: MissState

        /// The off day between sessions: trained yesterday, nothing due until
        /// the due day. Today should not push a lift (logging one stays allowed).
        /// False when nothing has been trained yet, on the day of a session,
        /// and from the due day onward.
        var isRestDay: Bool {
            guard let days = daysSinceLastHard else { return false }
            return days >= 1 && days < SessionSpacing.hardCadenceDays
        }
    }

    static func evaluate(
        sessions: [TrainingSessionSnapshot],
        now: Date,
        calendar: Calendar = .current
    ) -> Snapshot {
        let hard = sessions
            .filter { SessionSpacing.isHard($0.sessionType) }
            .sorted { $0.date < $1.date || ($0.date == $1.date && $0.createdAt < $1.createdAt) }

        guard let latest = hard.last else {
            return Snapshot(
                current: 0,
                lastChain: 0,
                best: 0,
                daysSinceLastHard: nil,
                lastHardDay: nil,
                miss: .none
            )
        }

        var chains: [Int] = []
        var run = 1
        for index in 1..<hard.count {
            let gapDays = SessionSpacing.calendarDays(
                from: hard[index - 1].date,
                to: hard[index].date,
                calendar: calendar
            )
            if gapDays <= SessionSpacing.hardCadenceDays {
                run += 1
            } else {
                chains.append(run)
                run = 1
            }
        }
        chains.append(run)

        let lastChain = chains.last ?? 0
        let best = chains.max() ?? 0
        let days = SessionSpacing.calendarDays(from: latest.date, to: now, calendar: calendar)
        let isLive = days <= SessionSpacing.hardCadenceDays

        return Snapshot(
            current: isLive ? lastChain : 0,
            lastChain: lastChain,
            best: best,
            daysSinceLastHard: days,
            lastHardDay: calendar.startOfDay(for: latest.date),
            miss: missState(daysSinceLastHard: days)
        )
    }

    /// Day 0: trained. Day 1: rest day, nothing due. Day 2: due day, whole day
    /// open. Day 3–4: one miss. Day 5+: two misses.
    static func missState(daysSinceLastHard days: Int) -> MissState {
        let cadence = SessionSpacing.hardCadenceDays
        if days < cadence {
            return .none
        }
        if days == cadence {
            return .approaching
        }
        if days <= cadence * 2 {
            return .oneMiss
        }
        return .twoMiss
    }

    /// Missed-session notification copy. The Today card only borrows the title.
    static let missTwiceTitle = "Don’t miss twice"
    static let missTwiceBody =
        "One miss is alright, but try not to miss twice. Consistency is what matters the most. Keep going."

    /// One short status line for the streak card. No explanation, no slogan.
    static func statusLabel(for miss: MissState) -> String? {
        switch miss {
        case .none:
            return nil
        case .approaching:
            return "Due today"
        case .oneMiss:
            return missTwiceTitle
        case .twoMiss:
            return "Missed twice"
        }
    }

    static func sessionWord(_ count: Int) -> String {
        count == 1 ? "1 session" : "\(count) sessions"
    }
}
