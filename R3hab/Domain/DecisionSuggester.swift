import Foundation

enum DecisionSuggester {
    /// Suggest decision from 24h response using **session-date chronology** only (KD-18).
    /// - recentResolvedNonRest: prior non-Rest Better/Same/Worse, sorted date desc, createdAt desc
    static func suggest(
        response: Response24h,
        recentResolvedNonRest: [Response24h],
        cleanN: Int = 3
    ) -> SessionDecision? {
        switch response {
        case .pending, .notApplicable:
            return nil
        case .same:
            return .stay
        case .better:
            let streak = recentResolvedNonRest.prefix(cleanN)
            let allClean = streak.count == cleanN
                && streak.allSatisfy { $0 == .better || $0 == .same }
            return allClean ? .progress : .stay
        case .worse:
            if recentResolvedNonRest.first == .worse {
                return .hardDrop
            }
            return .softCut
        }
    }

    /// Build prior list for session `current` from all sessions (any phase).
    static func priorsForSuggestion(
        current: TrainingSessionSnapshot,
        all: [TrainingSessionSnapshot]
    ) -> [Response24h] {
        clinicalResolvedSortedDescending(excluding: current.id, from: all)
            .map(\.response24h)
    }

    /// Resolved non-Rest sessions excluding `id`, newest session-date first.
    static func clinicalResolvedSortedDescending(
        excluding id: UUID?,
        from all: [TrainingSessionSnapshot]
    ) -> [TrainingSessionSnapshot] {
        all
            .filter { session in
                if let id, session.id == id { return false }
                if session.decision == .rest { return false }
                switch session.response24h {
                case .better, .same, .worse: return true
                case .pending, .notApplicable: return false
                }
            }
            .sorted { a, b in
                if a.date != b.date { return a.date > b.date }
                return a.createdAt > b.createdAt
            }
    }

    static func guidance(for decision: SessionDecision) -> String? {
        switch decision {
        case .softCut:
            return "Soft cut: stay in this phase, do less next time (−20–30% load, shorter holds, or fewer sets)."
        case .hardDrop:
            return "Hard drop: step back a phase when ready (e.g. C→B or B→A). Confirm phase change only if you intend it."
        case .stay, .progress, .rest:
            return nil
        }
    }
}
