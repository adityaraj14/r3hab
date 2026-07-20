import Foundation

struct SessionPreset: Identifiable, Hashable {
    let id: String
    let label: String
    let sessionType: SessionType
    let whatIDid: String
    let phases: Set<RehabPhase>?

    /// `phases == nil` means available in all phases.
    init(id: String, label: String, sessionType: SessionType, whatIDid: String, phases: Set<RehabPhase>? = nil) {
        self.id = id
        self.label = label
        self.sessionType = sessionType
        self.whatIDid = whatIDid
        self.phases = phases
    }

    static let all: [SessionPreset] = [
        .init(id: "wall", label: "Wall sit", sessionType: .isometrics, whatIDid: "Wall sit 3–4×20–30s", phases: [.bIsometrics, .aFlareDeLoad]),
        .init(id: "spanish", label: "Spanish squat", sessionType: .isometrics, whatIDid: "Spanish squat 3–4×20–30s", phases: [.bIsometrics, .cHeavySlowResistance]),
        .init(id: "ext", label: "Ext hold ~60°", sessionType: .isometrics, whatIDid: "Knee extension hold ~60° 3–4×20–30s", phases: [.bIsometrics]),
        .init(id: "lp", label: "Leg press HSR", sessionType: .hsrStrength, whatIDid: "Leg press 3–4×6–15 @ 3-1-3", phases: [.cHeavySlowResistance]),
        .init(id: "ke", label: "Knee extension HSR", sessionType: .hsrStrength, whatIDid: "Knee extension 3–4×6–15 @ 3-1-3", phases: [.cHeavySlowResistance]),
        .init(id: "land", label: "Low landings", sessionType: .energyStorage, whatIDid: "Low-volume landings / small jumps", phases: [.dEnergyStorage]),
        .init(id: "hit", label: "Short hitting", sessionType: .tennisSport, whatIDid: "Tennis: short hitting session", phases: [.eReturnToSport]),
        .init(id: "match", label: "Match play", sessionType: .tennisSport, whatIDid: "Tennis: match play", phases: [.eReturnToSport]),
        .init(id: "bike", label: "Easy bike", sessionType: .other, whatIDid: "Easy bike 5–10 min", phases: nil),
        .init(id: "custom", label: "Custom…", sessionType: .other, whatIDid: "", phases: nil)
    ]

    static func forPhase(_ phase: RehabPhase) -> [SessionPreset] {
        all.filter { preset in
            guard let phases = preset.phases else { return true }
            return phases.contains(phase)
        }
    }
}
