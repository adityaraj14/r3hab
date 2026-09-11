import Foundation

/// Rehab phase ladder A → E (user-owned; app only suggests).
enum RehabPhase: String, Codable, CaseIterable, Identifiable, Sendable {
    case aFlareDeLoad = "A"
    case bIsometrics = "B"
    case cHeavySlowResistance = "C"
    case dEnergyStorage = "D"
    case eReturnToSport = "E"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aFlareDeLoad: return "A · Flare de-load"
        case .bIsometrics: return "B · Isometrics"
        case .cHeavySlowResistance: return "C · Heavy slow resistance"
        case .dEnergyStorage: return "D · Energy storage"
        case .eReturnToSport: return "E · Return to sport"
        }
    }

    var shortTitle: String { rawValue }
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

/// Which resistance chart a structured load belongs on. Knee-only.
enum LoadRegion: String, Codable, CaseIterable, Identifiable, Sendable {
    case knee
    case ql

    var id: String { rawValue }

    var title: String {
        switch self {
        case .knee: return "Knee"
        case .ql: return "QL"
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
