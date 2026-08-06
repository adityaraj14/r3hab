import Foundation

struct SessionPreset: Identifiable, Hashable {
    let id: String
    let label: String
    let sessionType: SessionType
    let whatIDid: String
    let phases: Set<RehabPhase>?
    /// Shows sets / reps / load tracker.
    let tracksResistance: Bool
    /// Which Progress chart receives this load.
    let loadRegion: LoadRegion?

    /// `phases == nil` means available in all phases.
    init(
        id: String,
        label: String,
        sessionType: SessionType,
        whatIDid: String,
        phases: Set<RehabPhase>? = nil,
        tracksResistance: Bool = false,
        loadRegion: LoadRegion? = nil
    ) {
        self.id = id
        self.label = label
        self.sessionType = sessionType
        self.whatIDid = whatIDid
        self.phases = phases
        self.tracksResistance = tracksResistance
        self.loadRegion = loadRegion
    }

    static let all: [SessionPreset] = [
        .init(id: "wall", label: "Wall sit", sessionType: .isometrics, whatIDid: "Wall sit 3–4×20–30s", phases: [.bIsometrics, .aFlareDeLoad]),
        .init(id: "spanish", label: "Spanish squat", sessionType: .isometrics, whatIDid: "Spanish squat 3–4×20–30s", phases: [.bIsometrics, .cHeavySlowResistance]),
        .init(
            id: "ext",
            label: "Leg extension hold",
            sessionType: .isometrics,
            whatIDid: "Leg extension hold ~60°",
            phases: [.bIsometrics],
            tracksResistance: true,
            loadRegion: .knee
        ),
        .init(id: "lp", label: "Leg press HSR", sessionType: .hsrStrength, whatIDid: "Leg press 3–4×6–15 @ 3-1-3", phases: [.cHeavySlowResistance]),
        .init(
            id: "ke",
            label: "Leg extension HSR",
            sessionType: .hsrStrength,
            whatIDid: "Leg extension HSR @ 3s up / 3s down",
            phases: [.cHeavySlowResistance],
            tracksResistance: true,
            loadRegion: .knee
        ),
        .init(
            id: "hipThrust",
            label: "Hip thrust",
            sessionType: .hsrStrength,
            whatIDid: "Hip thrust",
            phases: nil,
            tracksResistance: true,
            loadRegion: .lowerBack
        ),
        .init(id: "land", label: "Low landings", sessionType: .energyStorage, whatIDid: "Low-volume landings / small jumps", phases: [.dEnergyStorage]),
        .init(id: "hit", label: "Short hitting", sessionType: .tennisSport, whatIDid: "Tennis: short hitting session", phases: [.eReturnToSport]),
        .init(id: "match", label: "Match play", sessionType: .tennisSport, whatIDid: "Tennis: match play", phases: [.eReturnToSport]),
        .init(id: "bike", label: "Easy bike", sessionType: .other, whatIDid: "Easy bike 5–10 min", phases: nil),
        .init(id: "custom", label: "Custom…", sessionType: .other, whatIDid: "", phases: nil)
    ]

    static let legExtensionIsometricId = "ext"
    static let legExtensionHSRId = "ke"
    static let hipThrustId = "hipThrust"

    static var hipThrust: SessionPreset {
        all.first { $0.id == hipThrustId }!
    }

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

    static func forPhase(_ phase: RehabPhase) -> [SessionPreset] {
        all.filter { preset in
            guard let phases = preset.phases else { return true }
            return phases.contains(phase)
        }
    }
}
