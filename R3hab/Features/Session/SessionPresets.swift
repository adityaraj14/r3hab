import Foundation

struct SessionPreset: Identifiable, Hashable {
    let id: String
    let label: String
    let sessionType: SessionType
    let whatIDid: String
    let phases: Set<RehabPhase>?
    let tracksResistance: Bool
    let loadRegion: LoadRegion
    /// Tracks this preset belongs to. `custom` is on every track.
    let tracks: Set<RehabTrackID>
    /// Prefer multi-set editor (HSR seated extension).
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
        loadRegion: LoadRegion = .knee,
        tracks: Set<RehabTrackID> = [.knee],
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
        self.tracks = tracks
        self.usesPerSetLogging = usesPerSetLogging
        self.usesIsoHoldLogging = usesIsoHoldLogging
    }

    static let all: [SessionPreset] = [
        .init(
            id: "ext",
            label: "Seated knee extension",
            sessionType: .isometrics,
            whatIDid: "Seated knee extension hold ~60°",
            phases: [.bIsometrics, .aFlareDeLoad],
            tracksResistance: true,
            usesPerSetLogging: true,
            usesIsoHoldLogging: true
        ),
        .init(
            id: "ke",
            label: "Seated extension HSR",
            sessionType: .hsrStrength,
            whatIDid: "Seated knee extension HSR",
            phases: [.cHeavySlowResistance],
            tracksResistance: true,
            usesPerSetLogging: true,
            usesIsoHoldLogging: false
        ),
        .init(id: "wall", label: "Wall sit", sessionType: .isometrics, whatIDid: "Wall sit 3–4×20–30s", phases: [.bIsometrics, .aFlareDeLoad]),
        .init(id: "spanish", label: "Spanish squat", sessionType: .isometrics, whatIDid: "Spanish squat 3–4×20–30s", phases: [.bIsometrics, .cHeavySlowResistance]),
        .init(id: "lp", label: "Leg press HSR", sessionType: .hsrStrength, whatIDid: "Leg press 3–4×6–15 @ 3-1-3", phases: [.cHeavySlowResistance]),
        .init(id: "land", label: "Low landings", sessionType: .energyStorage, whatIDid: "Low-volume landings / small jumps", phases: [.dEnergyStorage]),
        .init(id: "hit", label: "Short hitting", sessionType: .tennisSport, whatIDid: "Tennis: short hitting session", phases: [.eReturnToSport]),
        .init(id: "match", label: "Match play", sessionType: .tennisSport, whatIDid: "Tennis: match play", phases: [.eReturnToSport]),
        .init(id: "bike", label: "Easy bike", sessionType: .other, whatIDid: "Easy bike 5–10 min", phases: nil),
        .init(
            id: "ql-ht",
            label: "Hip thrusts",
            sessionType: .hsrStrength,
            whatIDid: "Hip thrusts",
            phases: [.aFlareDeLoad, .bIsometrics, .cHeavySlowResistance, .dEnergyStorage, .eReturnToSport],
            tracksResistance: true,
            loadRegion: .ql,
            tracks: [.ql],
            usesPerSetLogging: true
        ),
        .init(
            id: "ql-sb",
            label: "Standing side bends",
            sessionType: .hsrStrength,
            whatIDid: "Standing side bends",
            phases: [.aFlareDeLoad, .bIsometrics, .cHeavySlowResistance, .dEnergyStorage, .eReturnToSport],
            tracksResistance: true,
            loadRegion: .ql,
            tracks: [.ql],
            usesPerSetLogging: true
        ),
        .init(
            id: "ql-walk",
            label: "Walking",
            sessionType: .other,
            whatIDid: "Easy walk 10–20 min",
            phases: [.aFlareDeLoad, .bIsometrics, .cHeavySlowResistance, .dEnergyStorage, .eReturnToSport],
            tracksResistance: false,
            loadRegion: .ql,
            tracks: [.ql]
        ),
        .init(
            id: "custom",
            label: "Custom…",
            sessionType: .other,
            whatIDid: "",
            phases: nil,
            tracks: [.knee, .ql]
        )
    ]

    static let seatedExtensionIsometricId = "ext"
    static let seatedExtensionHSRId = "ke"
    static let legExtensionIsometricId = seatedExtensionIsometricId
    static let legExtensionHSRId = seatedExtensionHSRId

    static func resistancePreset(for phase: RehabPhase) -> SessionPreset? {
        preferred(for: phase, primaryLoadID: PrimaryLoadCatalog.defaultID)
    }

    /// Iso variant in A/B; HSR variant from C onward. Unknown ids fall back to seated extension.
    static func preferred(for phase: RehabPhase, primaryLoadID: String) -> SessionPreset {
        let option = PrimaryLoadCatalog.option(for: primaryLoadID)
        let presetID: String
        switch phase {
        case .aFlareDeLoad, .bIsometrics:
            presetID = option.isometricPresetID
        case .cHeavySlowResistance, .dEnergyStorage, .eReturnToSport:
            presetID = option.hsrPresetID
        }
        return all.first { $0.id == presetID }
            ?? all.first { $0.tracks.contains(option.track) && $0.id != "custom" }
            ?? all.first { $0.id == seatedExtensionIsometricId }
            ?? all[0]
    }

    func isPreferred(for primaryLoadID: String) -> Bool {
        PrimaryLoadCatalog.presetIDs(for: primaryLoadID).contains(id)
    }

    var isPrimarySeatedExtension: Bool {
        isPreferred(for: PrimaryLoadCatalog.defaultID)
    }

    static func forPhase(
        _ phase: RehabPhase,
        primaryLoadID: String = PrimaryLoadCatalog.defaultID
    ) -> [SessionPreset] {
        let track = PrimaryLoadCatalog.option(for: primaryLoadID).track
        let filtered = all.enumerated().filter { _, preset in
            guard preset.tracks.contains(track) else { return false }
            guard let phases = preset.phases else { return true }
            return phases.contains(phase)
        }
        return filtered
            .sorted { a, b in
                let ap = a.element.isPreferred(for: primaryLoadID) ? 0 : 1
                let bp = b.element.isPreferred(for: primaryLoadID) ? 0 : 1
                if ap != bp { return ap < bp }
                return a.offset < b.offset
            }
            .map(\.element)
    }
}
