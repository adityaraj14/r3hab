import Foundation

struct SessionPreset: Identifiable, Hashable {
    let id: String
    let label: String
    let sessionType: SessionType
    let whatIDid: String
    let phases: Set<RehabPhase>?
    let tracksResistance: Bool
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
        usesPerSetLogging: Bool = false,
        usesIsoHoldLogging: Bool = false
    ) {
        self.id = id
        self.label = label
        self.sessionType = sessionType
        self.whatIDid = whatIDid
        self.phases = phases
        self.tracksResistance = tracksResistance
        self.usesPerSetLogging = usesPerSetLogging
        self.usesIsoHoldLogging = usesIsoHoldLogging
    }

    /// Knee chips are the two loaders (Adi, PR #18): no "Easy bike", no
    /// "Custom…". Iso variants in A/B, HSR variants in C. Other session
    /// types stay reachable via the Type picker and free text.
    static let all: [SessionPreset] = [
        .init(
            id: "ext",
            label: "Seated extension",
            sessionType: .isometrics,
            whatIDid: "Seated extension hold ~60°",
            phases: [.bIsometrics, .aFlareDeLoad],
            tracksResistance: true,
            usesPerSetLogging: true,
            usesIsoHoldLogging: true
        ),
        .init(
            id: "ke",
            label: "Seated extension",
            sessionType: .hsrStrength,
            whatIDid: "Seated extension",
            phases: [.cHeavySlowResistance],
            tracksResistance: true,
            usesPerSetLogging: true,
            usesIsoHoldLogging: false
        ),
        .init(
            id: "lp-iso",
            label: "Leg press",
            sessionType: .isometrics,
            whatIDid: "Leg press hold",
            phases: [.bIsometrics, .aFlareDeLoad],
            tracksResistance: true,
            usesPerSetLogging: true,
            usesIsoHoldLogging: true
        ),
        .init(
            id: "lp",
            label: "Leg press",
            sessionType: .hsrStrength,
            whatIDid: "Leg press",
            phases: [.cHeavySlowResistance],
            tracksResistance: true,
            usesPerSetLogging: true,
            usesIsoHoldLogging: false
        )
    ]

    static let seatedExtensionIsometricId = "ext"
    static let seatedExtensionHSRId = "ke"
    static let legPressIsometricId = "lp-iso"
    static let legPressHSRId = "lp"
    static let legExtensionIsometricId = seatedExtensionIsometricId
    static let legExtensionHSRId = seatedExtensionHSRId

    static func resistancePreset(for phase: RehabPhase) -> SessionPreset? {
        preferred(for: phase, primaryLoadID: PrimaryLoadCatalog.defaultID)
    }

    /// Iso variant in A/B; HSR variant in C. Unknown ids fall back to seated extension.
    static func preferred(for phase: RehabPhase, primaryLoadID: String) -> SessionPreset {
        let option = PrimaryLoadCatalog.option(for: primaryLoadID)
        let presetID: String
        switch phase {
        case .aFlareDeLoad, .bIsometrics:
            presetID = option.isometricPresetID
        case .cHeavySlowResistance:
            presetID = option.hsrPresetID
        }
        return all.first { $0.id == presetID }
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
        let filtered = all.enumerated().filter { _, preset in
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
