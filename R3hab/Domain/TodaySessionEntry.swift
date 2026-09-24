import Foundation

struct TodaySessionLoad: Equatable, Sendable {
    var warmupNote: String?
    var workLines: [String]

    var hasLines: Bool {
        warmupNote != nil || !workLines.isEmpty
    }
}

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

    static func resolve(
        isRestDay: Bool,
        hasDraft: Bool,
        todaySessions: [TrainingSessionSnapshot],
        target: LoadPrescription,
        laterality: SetLaterality
    ) -> TodaySessionEntry {
        if !todaySessions.isEmpty {
            return .logged(
                load(from: todaySessions.flatMap(\.resistanceSets)),
                status: status(for: todaySessions)
            )
        }
        if hasDraft {
            return .resumeDraft
        }
        if isRestDay {
            return .rest
        }
        return .target(load(from: target, laterality: laterality))
    }

    static func status(for sessions: [TrainingSessionSnapshot]) -> String {
        if let pending = sessions.first(where: { !$0.hasLoggedPainAfter }) {
            return "During \(pending.painDuring) · after not logged"
        }
        return sessions.count == 1 ? "Logged" : "\(sessions.count) logged"
    }

    private static func load(from target: LoadPrescription, laterality: SetLaterality) -> TodaySessionLoad {
        load(from: [SessionPrefill.warmupSet(loadLbs: target.loadLbs)]
            + SessionPrefill.workSets(from: target, laterality: laterality))
    }

    private static func load(from sets: [ResistanceSet]) -> TodaySessionLoad {
        let warmup = sets.filter(\.isWarmup)
        let work = sets.filter { !$0.isWarmup }
        return TodaySessionLoad(
            warmupNote: SessionSummary.compactResistance(warmup),
            workLines: SessionSummary.groupWorkSets(work).map(workLine(for:))
        )
    }

    private static func workLine(for pair: WorkSetPair) -> String {
        let dose = SessionSummary.historyDose(reps: pair.reps, holdSeconds: pair.holdSeconds)
        if pair.loadsMatch {
            guard let lbs = pair.leftLoad else { return dose }
            return [dose, "@ \(LoadCopy.labeled(lbs))"].filter { !$0.isEmpty }.joined(separator: " ")
        }
        let left = pair.leftLoad.map(LoadCopy.labeled) ?? "—"
        let right = pair.rightLoad.map(LoadCopy.labeled) ?? "—"
        return [dose, "L @ \(left) / R @ \(right)"].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
