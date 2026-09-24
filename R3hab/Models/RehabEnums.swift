import Foundation

/// Rehab phase ladder A → C (user-owned; app only suggests). Matches the
/// onboarding choices: Flare / Isometrics / Heavy slow resistance.
enum RehabPhase: String, Codable, CaseIterable, Identifiable, Sendable {
    case aFlareDeLoad = "A"
    case bIsometrics = "B"
    case cHeavySlowResistance = "C"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aFlareDeLoad: return "A · Flare de-load"
        case .bIsometrics: return "B · Isometrics"
        case .cHeavySlowResistance: return "C · Heavy slow resistance"
        }
    }

    var shortTitle: String { rawValue }

    /// Phases D (energy storage) and E (return to sport) were removed. Rows
    /// and settings that still carry them read as C, the last phase that
    /// exists, so nothing in the ladder moves backwards on upgrade.
    static let retiredRawValues: Set<String> = ["D", "E"]
    static let retiredRemapTarget: RehabPhase = .cHeavySlowResistance

    /// Stored raw → phase. Retired raws land on C; anything else unknown
    /// falls back to A, the same default as a fresh install.
    static func normalized(rawValue: String) -> RehabPhase {
        if retiredRawValues.contains(rawValue) {
            return retiredRemapTarget
        }
        return RehabPhase(rawValue: rawValue) ?? .aFlareDeLoad
    }

    static func normalizedRawValue(_ rawValue: String) -> String {
        normalized(rawValue: rawValue).rawValue
    }

    static func needsRemap(_ rawValue: String) -> Bool {
        normalizedRawValue(rawValue) != rawValue
    }
}

enum SessionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case isometrics
    case hsrStrength
    case energyStorage
    case tennisSport
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .isometrics: return "Isometrics"
        case .hsrStrength: return "HSR"
        case .energyStorage: return "Energy storage"
        case .tennisSport: return "Tennis / sport"
        case .other: return "Other"
        }
    }

    /// Compact chip label for Log list.
    var shortTag: String {
        switch self {
        case .isometrics: return "Isometrics"
        case .hsrStrength: return "HSR"
        case .energyStorage: return "Energy"
        case .tennisSport: return "Tennis"
        case .other: return "Other"
        }
    }
}

/// How SessionEditor opens for a new log.
enum SessionLogFocus: String, Sendable {
    case general
    case kneeResistance
}

enum Response24h: String, Codable, CaseIterable, Identifiable, Sendable {
    case pending
    case better
    case same
    case worse
    case notApplicable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: return "Pending"
        case .better: return "Better"
        case .same: return "Same"
        case .worse: return "Worse"
        case .notApplicable: return "N/A"
        }
    }
}

/// Session pain scores are stored as `Int`. `-1` means “not logged yet”
/// so SwiftData does not need an optional-column migration.
enum PainScore {
    static let notLogged = -1
    static let validRange = 0...10

    static func isLogged(_ value: Int) -> Bool {
        validRange.contains(value)
    }

    static func display(_ value: Int) -> String {
        isLogged(value) ? String(value) : "—"
    }

    static func chartValue(_ value: Int) -> Double? {
        isLogged(value) ? Double(value) : nil
    }

    static func optional(_ value: Int) -> Int? {
        isLogged(value) ? value : nil
    }
}

enum SessionSaveIssue: Equatable, Sendable {
    case missingPainDuring
    case painDuringOutOfRange
    case painAfterOutOfRange
    case emptyWhatIDid
    case nonPositiveReps
    case nonPositiveHold
    case negativeLoad
    case nonPositiveSteps
    case nonPositiveDuration

    var message: String {
        switch self {
        case .missingPainDuring:
            return "Pain during is required (0–10)."
        case .painDuringOutOfRange:
            return "Pain during must be 0–10."
        case .painAfterOutOfRange:
            return "Pain after must be 0–10."
        case .emptyWhatIDid:
            return "Describe what you did (or pick a preset)."
        case .nonPositiveReps:
            return "Reps must be positive."
        case .nonPositiveHold:
            return "Hold time must be positive."
        case .negativeLoad:
            return "Load must be ≥ 0."
        case .nonPositiveSteps:
            return "Steps must be positive."
        case .nonPositiveDuration:
            return "Minutes must be positive."
        }
    }
}

enum SessionSaveValidation {
    static func validate(
        painDuring: Int?,
        painAfter: Int?,
        whatIDid: String,
        sets: [ResistanceSet]
    ) -> SessionSaveIssue? {
        guard let painDuring else { return .missingPainDuring }
        guard PainScore.isLogged(painDuring) else { return .painDuringOutOfRange }
        if let painAfter, !PainScore.isLogged(painAfter) {
            return .painAfterOutOfRange
        }
        let text = whatIDid.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .emptyWhatIDid }
        for row in sets {
            if let r = row.reps, r <= 0 { return .nonPositiveReps }
            if let h = row.holdSeconds, h <= 0 { return .nonPositiveHold }
            if let l = row.loadLbs, l < 0 { return .negativeLoad }
            if let steps = row.steps, steps <= 0 { return .nonPositiveSteps }
            if let minutes = row.durationMinutes, minutes <= 0 { return .nonPositiveDuration }
        }
        return nil
    }
}

enum SessionDecision: String, Codable, CaseIterable, Identifiable, Sendable {
    case stay
    case softCut
    case progress
    case hardDrop
    case rest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stay: return "Stay"
        case .softCut: return "Soft cut"
        case .progress: return "Progress"
        case .hardDrop: return "Hard drop"
        case .rest: return "Rest"
        }
    }
}
