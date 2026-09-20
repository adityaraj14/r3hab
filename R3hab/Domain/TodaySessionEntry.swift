import Foundation

struct TodaySessionLoad: Equatable, Sendable {
    var warmupNote: String?
    var workLines: [String]

    var hasLines: Bool {
        warmupNote != nil || !workLines.isEmpty
    }
}

/// Today middle-row content. Rest cannot carry an HSR target string.
enum TodaySessionEntry: Equatable, Sendable {
    case rest
    case resumeDraft
    case target(TodaySessionLoad)
    case logged(TodaySessionLoad, status: String)

    var load: TodaySessionLoad? {
        switch self {
        case .target(let load), .logged(let load, _):
            return load
        case .rest, .resumeDraft:
            return nil
        }
    }

    var loggedStatus: String? {
        if case .logged(_, let status) = self {
            return status
        }
        return nil
    }

    /// Mirrors `HomeView.sessionRowValue` after #31: empty days always get `todayLine`.
    static func resolve(
        isRestDay: Bool,
        hasDraft: Bool,
        todaySessions: [TrainingSessionSnapshot],
        target: LoadPrescription,
        laterality: SetLaterality
    ) -> TodaySessionEntry {
        _ = isRestDay
        _ = laterality
        if todaySessions.isEmpty, hasDraft {
            return .resumeDraft
        }
        if todaySessions.isEmpty {
            return .target(TodaySessionLoad(warmupNote: nil, workLines: [target.todayLine]))
        }
        return .logged(
            TodaySessionLoad(warmupNote: nil, workLines: []),
            status: status(for: todaySessions)
        )
    }

    static func status(for sessions: [TrainingSessionSnapshot]) -> String {
        if let pending = sessions.first(where: { !$0.hasLoggedPainAfter }) {
            return "During \(pending.painDuring) · after not logged"
        }
        return sessions.count == 1 ? "Logged" : "\(sessions.count) logged"
    }
}
