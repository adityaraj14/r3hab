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
        case .hsrStrength: return "HSR / strength"
        case .energyStorage: return "Energy storage"
        case .tennisSport: return "Tennis / sport"
        case .other: return "Other"
        }
    }
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
