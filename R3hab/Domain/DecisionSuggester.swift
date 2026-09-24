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
            // Advice only. Option B holds the gold-card load on Worse;
            // soft cut does not rewrite that prescription.
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
        SessionDraft.finalized(all)
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

    /// The one sentence under Better / Same / Worse. The card is the response;
    /// this is the call.
    static func closeLine(for decision: SessionDecision) -> String {
        switch decision {
        case .stay:
            return "Stay. Same load next time."
        case .progress:
            return "Progress. A little more next time."
        case .softCut:
            return "Soft cut. A little less next time."
        case .hardDrop:
            return "Hard drop. Step back a phase."
        case .rest:
            return "Rest. No load judgment."
        }
    }
}

/// Gentle, non-blocking load hint after a morning log or 24h resolve.
enum LoadNudge: Equatable, Identifiable {
    case easeOffMorning(previous: Int, current: Int)
    case easeOffWorse
    case progress(cleanCount: Int)

    var id: String {
        switch self {
        case .easeOffMorning(let previous, let current):
            return "ease-morning-\(previous)-\(current)"
        case .easeOffWorse:
            return "ease-worse"
        case .progress(let count):
            return "progress-\(count)"
        }
    }

    var title: String {
        switch self {
        case .easeOffMorning, .easeOffWorse:
            return "Take the next session easier"
        case .progress:
            return "Ready to add load"
        }
    }

    var message: String {
        switch self {
        case .easeOffMorning(let previous, let current):
            return "This morning’s pain is \(current), up from \(previous) the morning of your last workout. Next time, try a bit less — lower the load, do fewer reps, or shorten the holds. One change is enough."
        case .easeOffWorse:
            return "Pain was worse after that session. Next time, try a bit less — about 20–30% less load, fewer sets, or shorter holds. One change is enough."
        case .progress:
            return "Pain held steady — next time, try a bit more weight with the same sets and reps."
        }
    }
}

enum LoadNudgeEvaluator {
    static let progressStreakLength = 5

    /// Next-morning AM higher than the AM on (or just before) yesterday’s workout.
    static func afterMorningPain(
        todayAM: Int?,
        checkInDate: Date,
        checkIns: [DailyCheckInSnapshot],
        sessions: [TrainingSessionSnapshot],
        calendar: Calendar = .current
    ) -> LoadNudge? {
        guard let todayAM else { return nil }
        let today = calendar.startOfDay(for: checkInDate)
        guard let session = mostRecentWorkout(before: today, sessions: sessions, calendar: calendar) else {
            return nil
        }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              calendar.isDate(session.date, inSameDayAs: yesterday) else {
            return nil
        }
        guard let baseline = baselineMorningPain(
            onOrBefore: calendar.startOfDay(for: session.date),
            checkIns: checkIns,
            calendar: calendar
        ) else {
            return nil
        }
        guard todayAM > baseline else { return nil }
        return .easeOffMorning(previous: baseline, current: todayAM)
    }

    /// Worse resolve → ease off. Five (or 10, 15, …) clean Better/Same resolves → progress.
    static func afterResolve(
        response: Response24h,
        current: TrainingSessionSnapshot,
        all: [TrainingSessionSnapshot]
    ) -> LoadNudge? {
        switch response {
        case .worse:
            return .easeOffWorse
        case .better, .same:
            let streak = cleanStreak(including: response, current: current, all: all)
            guard streak >= progressStreakLength, streak.isMultiple(of: progressStreakLength) else {
                return nil
            }
            return .progress(cleanCount: streak)
        case .pending, .notApplicable:
            return nil
        }
    }

    static func mostRecentWorkout(
        before day: Date,
        sessions: [TrainingSessionSnapshot],
        calendar: Calendar
    ) -> TrainingSessionSnapshot? {
        let start = calendar.startOfDay(for: day)
        return SessionDraft.finalized(sessions)
            .filter { session in
                guard session.decision != .rest else { return false }
                if session.response24h == .notApplicable { return false }
                return calendar.startOfDay(for: session.date) < start
            }
            .sorted { a, b in
                if a.date != b.date { return a.date > b.date }
                return a.createdAt > b.createdAt
            }
            .first
    }

    static func baselineMorningPain(
        onOrBefore day: Date,
        checkIns: [DailyCheckInSnapshot],
        calendar: Calendar
    ) -> Int? {
        let start = calendar.startOfDay(for: day)
        return checkIns
            .filter { calendar.startOfDay(for: $0.date) <= start && $0.restingPainAM != nil }
            .sorted { $0.date > $1.date }
            .first?
            .restingPainAM
    }

    static func cleanStreak(
        including response: Response24h,
        current: TrainingSessionSnapshot,
        all: [TrainingSessionSnapshot]
    ) -> Int {
        guard response == .better || response == .same else { return 0 }
        var count = 1
        let priors = all
            .filter { $0.id != current.id }
            .sorted { a, b in
                if a.date != b.date { return a.date > b.date }
                return a.createdAt > b.createdAt
            }
        for session in priors {
            if session.decision == .rest || session.response24h == .notApplicable {
                break
            }
            if session.response24h == .pending {
                continue
            }
            if session.response24h == .worse {
                break
            }
            if session.response24h == .better || session.response24h == .same {
                count += 1
            }
        }
        return count
    }
}
