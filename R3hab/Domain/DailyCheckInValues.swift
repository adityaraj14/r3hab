import Foundation

enum DailyCheckInFocus: Equatable, Sendable {
    case morning
    case evening
    case full
}

/// Value-type copy of one day’s check-in. Editors hold this — never the live
/// SwiftData `DailyCheckIn` — so a long background cannot leave the UI writing
/// through an invalidated model. Persistence is fetch-or-insert by dayKey on
/// whatever context is current at save time.
struct DailyCheckInValues: Equatable, Sendable {
    var restingPainAM: Int?
    var dailyPainPM: Int?
    var steps: Int?
    var phase: RehabPhase
    var notes: String
    var declineSquatL: Int?
    var declineSquatR: Int?

    init(
        restingPainAM: Int? = nil,
        dailyPainPM: Int? = nil,
        steps: Int? = nil,
        phase: RehabPhase = .aFlareDeLoad,
        notes: String = "",
        declineSquatL: Int? = nil,
        declineSquatR: Int? = nil
    ) {
        self.restingPainAM = restingPainAM
        self.dailyPainPM = dailyPainPM
        self.steps = steps
        self.phase = phase
        self.notes = notes
        self.declineSquatL = declineSquatL
        self.declineSquatR = declineSquatR
    }
}

enum DailyCheckInMerge {
    enum StepsParse: Equatable, Sendable {
        case empty
        case value(Int)
        case invalid
    }

    /// Whole number ≥ 0, or empty. Anything else is a user error.
    static func steps(from text: String) -> StepsParse {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        guard let value = Int(trimmed), value >= 0 else { return .invalid }
        return .value(value)
    }

    /// A focused editor only overwrites the fields it showed. Morning keeps the
    /// evening fields the row already had, and vice versa. Notes always write.
    static func merge(
        existing: DailyCheckInValues?,
        draft: DailyCheckInValues,
        focus: DailyCheckInFocus
    ) -> DailyCheckInValues {
        var result = existing ?? DailyCheckInValues(phase: draft.phase)
        switch focus {
        case .morning:
            result.restingPainAM = draft.restingPainAM
            result.phase = draft.phase
        case .evening:
            result.dailyPainPM = draft.dailyPainPM
            result.steps = draft.steps
            result.declineSquatL = draft.declineSquatL
            result.declineSquatR = draft.declineSquatR
        case .full:
            result = draft
        }
        result.notes = draft.notes
        return result
    }

    /// Scores the focused editor showed must be 0–10 when set.
    static func validationError(draft: DailyCheckInValues, focus: DailyCheckInFocus) -> String? {
        let scores: [Int?]
        switch focus {
        case .morning:
            scores = [draft.restingPainAM]
        case .evening:
            scores = [draft.dailyPainPM, draft.declineSquatL, draft.declineSquatR]
        case .full:
            scores = [draft.restingPainAM, draft.dailyPainPM, draft.declineSquatL, draft.declineSquatR]
        }
        for score in scores {
            if let score, !PainScore.validRange.contains(score) {
                return "Pain scores must be 0–10."
            }
        }
        return nil
    }
}
