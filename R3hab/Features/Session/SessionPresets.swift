import Foundation

struct SessionPreset: Identifiable, Hashable {
    let id: String
    let label: String
    let sessionType: SessionType
    let whatIDid: String
    let phases: Set<RehabPhase>?
    let tracksResistance: Bool
    let loadRegion: LoadRegion?
    let track: RehabTrackID
    /// Prefer multi-set editor (HSR knee / hip thrust).
    let usesPerSetLogging: Bool
    /// Prefer isometric hold fields (reps × time × load).
    let usesIsoHoldLogging: Bool

    init(
        id: String,
        label: String,
        sessionType: SessionType,
        whatIDid: String,
        phases: Set<RehabPhase>? = nil,
        tracksResistance: Bool = false,
        loadRegion: LoadRegion? = nil,
        track: RehabTrackID = .knee,
        usesPerSetLogging: Bool = false,
        usesIsoHoldLogging: Bool = false
    ) {
        self.id = id
        self.label = label
        self.sessionType = sessionType
        self.whatIDid = whatIDid
        self.phases = phases
        self.tracksResistance = tracksResistance
        self.loadRegion = loadRegion
        self.track = track
        self.usesPerSetLogging = usesPerSetLogging
        self.usesIsoHoldLogging = usesIsoHoldLogging
    }

    static let all: [SessionPreset] = [
        .init(id: "wall", label: "Wall sit", sessionType: .isometrics, whatIDid: "Wall sit 3–4×20–30s", phases: [.bIsometrics, .aFlareDeLoad], track: .knee),
        .init(id: "spanish", label: "Spanish squat", sessionType: .isometrics, whatIDid: "Spanish squat 3–4×20–30s", phases: [.bIsometrics, .cHeavySlowResistance], track: .knee),
        .init(
            id: "ext",
            label: "Leg extension hold",
            sessionType: .isometrics,
            whatIDid: "Leg extension hold ~60°",
            phases: [.bIsometrics],
            tracksResistance: true,
            loadRegion: .knee,
            track: .knee,
            usesPerSetLogging: true,
            usesIsoHoldLogging: true
        ),
        .init(id: "lp", label: "Leg press HSR", sessionType: .hsrStrength, whatIDid: "Leg press 3–4×6–15 @ 3-1-3", phases: [.cHeavySlowResistance], track: .knee),
        .init(
            id: "ke",
            label: "Leg extension HSR",
            sessionType: .hsrStrength,
            whatIDid: "Leg extension HSR",
            phases: [.cHeavySlowResistance],
            tracksResistance: true,
            loadRegion: .knee,
            track: .knee,
            usesPerSetLogging: true,
            usesIsoHoldLogging: false
        ),
        .init(
            id: "hipThrust",
            label: "Hip thrust",
            sessionType: .hsrStrength,
            whatIDid: "Hip thrust",
            phases: nil,
            tracksResistance: true,
            loadRegion: .lowerBack,
            track: .lowerBack,
            usesPerSetLogging: true
        ),
        .init(
            id: "sidePlank",
            label: "Side plank",
            sessionType: .isometrics,
            whatIDid: "Side plank hold",
            phases: nil,
            tracksResistance: true,
            loadRegion: .lowerBack,
            track: .lowerBack,
            usesIsoHoldLogging: true
        ),
        .init(
            id: "suitcase",
            label: "Suitcase hold",
            sessionType: .isometrics,
            whatIDid: "Suitcase hold",
            phases: nil,
            tracksResistance: true,
            loadRegion: .lowerBack,
            track: .lowerBack,
            usesIsoHoldLogging: true
        ),
        .init(id: "land", label: "Low landings", sessionType: .energyStorage, whatIDid: "Low-volume landings / small jumps", phases: [.dEnergyStorage], track: .knee),
        .init(id: "hit", label: "Short hitting", sessionType: .tennisSport, whatIDid: "Tennis: short hitting session", phases: [.eReturnToSport], track: .knee),
        .init(id: "match", label: "Match play", sessionType: .tennisSport, whatIDid: "Tennis: match play", phases: [.eReturnToSport], track: .knee),
        .init(id: "bike", label: "Easy bike", sessionType: .other, whatIDid: "Easy bike 5–10 min", phases: nil, track: .knee),
        .init(id: "custom", label: "Custom…", sessionType: .other, whatIDid: "", phases: nil, track: .knee)
    ]

    static let legExtensionIsometricId = "ext"
    static let legExtensionHSRId = "ke"
    static let hipThrustId = "hipThrust"
    static let sidePlankId = "sidePlank"
    static let suitcaseId = "suitcase"

    static var hipThrust: SessionPreset { all.first { $0.id == hipThrustId }! }
    static var sidePlank: SessionPreset { all.first { $0.id == sidePlankId }! }
    static var suitcase: SessionPreset { all.first { $0.id == suitcaseId }! }

    static func resistancePreset(for phase: RehabPhase) -> SessionPreset? {
        switch phase {
        case .bIsometrics:
            return all.first { $0.id == legExtensionIsometricId }
        case .cHeavySlowResistance:
            return all.first { $0.id == legExtensionHSRId }
        default:
            return nil
        }
    }

    static func forPhase(_ phase: RehabPhase, track: RehabTrackID? = nil) -> [SessionPreset] {
        all.filter { preset in
            if let track, preset.track != track, preset.id != "custom", preset.id != "bike" {
                // bike/custom available on knee track only for simplicity
                if track == .lowerBack { return preset.track == .lowerBack }
            }
            if let track, track == .lowerBack {
                return preset.track == .lowerBack
            }
            if let track, track == .knee {
                return preset.track == .knee
            }
            guard let phases = preset.phases else { return true }
            return phases.contains(phase)
        }
    }

    static func forTrack(_ track: RehabTrackID, phase: RehabPhase) -> [SessionPreset] {
        switch track {
        case .lowerBack:
            return all.filter { $0.track == .lowerBack }
        case .knee:
            return all.filter { preset in
                guard preset.track == .knee else { return false }
                guard let phases = preset.phases else { return true }
                return phases.contains(phase)
            }
        }
    }
}
