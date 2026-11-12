import Foundation

struct SessionPreset: Identifiable, Hashable {
    let id: String
    let injuryID: String
    let label: String
    let sessionType: SessionType
    let whatIDid: String
    let phases: Set<RehabPhase>?
    let tracksResistance: Bool
    /// Prefer multi-set editor (HSR seated leg extension).
    let usesPerSetLogging: Bool
    /// Prefer isometric hold fields (reps × time × load).
    let usesIsoHoldLogging: Bool
    /// Walk log: steps and optional minutes. Not a resistance ladder.
    let tracksWalk: Bool

    init(
        id: String,
        injuryID: String = "patellar-tendinopathy",
        label: String,
        sessionType: SessionType,
        whatIDid: String,
        phases: Set<RehabPhase>? = nil,
        tracksResistance: Bool = false,
        usesPerSetLogging: Bool = false,
        usesIsoHoldLogging: Bool = false,
        tracksWalk: Bool = false
    ) {
        self.id = id
        self.injuryID = injuryID
        self.label = label
        self.sessionType = sessionType
        self.whatIDid = whatIDid
        self.phases = phases
        self.tracksResistance = tracksResistance
        self.usesPerSetLogging = usesPerSetLogging
        self.usesIsoHoldLogging = usesIsoHoldLogging
        self.tracksWalk = tracksWalk
    }

    /// Knee chips are the two loaders (Adi, PR #18): no "Easy bike", no
    /// "Custom…". Iso variants in A/B, HSR variants in C. Other session
    /// types stay reachable via the Type picker and free text.
    static let all: [SessionPreset] = [
        .init(
            id: "ext",
            label: "Seated leg extension hold",
            sessionType: .isometrics,
            whatIDid: "Seated leg extension hold",
            phases: [.bIsometrics, .aFlareDeLoad, .calmTendon, .heavySlow, .heavier, .springiness],
            tracksResistance: true,
            usesPerSetLogging: true,
            usesIsoHoldLogging: true
        ),
        .init(
            id: "ke",
            label: "Seated leg extension",
            sessionType: .hsrStrength,
            whatIDid: "Seated leg extension",
            phases: [.cHeavySlowResistance, .heavySlow, .heavier, .springiness],
            tracksResistance: true,
            usesPerSetLogging: true,
            usesIsoHoldLogging: false
        ),
        .init(
            id: "lp-iso",
            label: "Leg press",
            sessionType: .isometrics,
            whatIDid: "Leg press hold",
            phases: [.bIsometrics, .aFlareDeLoad, .calmTendon, .heavySlow, .heavier, .springiness],
            tracksResistance: true,
            usesPerSetLogging: true,
            usesIsoHoldLogging: true
        ),
        .init(
            id: "lp",
            label: "Leg press",
            sessionType: .hsrStrength,
            whatIDid: "Leg press",
            phases: [.cHeavySlowResistance, .heavySlow, .heavier, .springiness],
            tracksResistance: true,
            usesPerSetLogging: true,
            usesIsoHoldLogging: false
        ),
        .init(
            id: "slp",
            label: "Single-leg leg press",
            sessionType: .hsrStrength,
            whatIDid: "Single-leg leg press",
            phases: [.aFlareDeLoad, .bIsometrics, .calmTendon],
            tracksResistance: true,
            usesPerSetLogging: true
        ),
        .init(
            id: "hip",
            label: "Side-lying hip abduction",
            sessionType: .other,
            whatIDid: "Side-lying hip abduction",
            phases: [.aFlareDeLoad, .bIsometrics, .calmTendon],
            tracksResistance: true,
            usesPerSetLogging: true
        ),
        .init(
            id: "calf",
            label: "Calf raise",
            sessionType: .other,
            whatIDid: "Calf raise",
            phases: [.aFlareDeLoad, .bIsometrics, .calmTendon],
            tracksResistance: true,
            usesPerSetLogging: true
        ),
        .init(
            id: "spanish",
            label: "Spanish squat",
            sessionType: .isometrics,
            whatIDid: "Spanish squat",
            phases: [.heavier],
            tracksResistance: true,
            usesPerSetLogging: true,
            usesIsoHoldLogging: true
        ),
        .init(
            id: "pogo",
            label: "Pogo hop",
            sessionType: .energyStorage,
            whatIDid: "Pogo hop",
            phases: [.springiness],
            tracksResistance: true,
            usesPerSetLogging: true
        ),
        .init(
            id: "box",
            label: "Box jump-up",
            sessionType: .energyStorage,
            whatIDid: "Box jump-up",
            phases: [.springiness],
            tracksResistance: true,
            usesPerSetLogging: true
        ),
        .init(
            id: "land",
            label: "Landing",
            sessionType: .energyStorage,
            whatIDid: "Landing",
            phases: [.springiness],
            tracksResistance: true,
            usesPerSetLogging: true
        ),
        .init(
            id: "ql-walk",
            injuryID: "ql-strain",
            label: "Walking",
            sessionType: .other,
            whatIDid: "Walking",
            phases: Set(RehabPhase.allCases),
            tracksWalk: true
        ),
        .init(
            id: "ql-side-bend",
            injuryID: "ql-strain",
            label: "Side bend",
            sessionType: .other,
            whatIDid: "Side bend",
            phases: Set(RehabPhase.allCases),
            tracksResistance: true,
            usesPerSetLogging: true
        ),
        .init(
            id: "ql-hip-thrust",
            injuryID: "ql-strain",
            label: "Hip thrust",
            sessionType: .other,
            whatIDid: "Hip thrust",
            phases: Set(RehabPhase.allCases),
            tracksResistance: true,
            usesPerSetLogging: true
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

    /// Calm weeks use the hold, or the single-leg press when that is the chosen lift.
    /// Later weeks use the heavy slow variant.
    static func preferred(for phase: RehabPhase, primaryLoadID: String) -> SessionPreset {
        let option = PrimaryLoadCatalog.option(for: primaryLoadID)
        let presetID: String
        if !option.usesPatellarLadder {
            presetID = option.hsrPresetID
        } else {
            switch RehabPhase.planPhase(for: phase) {
            case .calmTendon:
                presetID = option.id == PrimaryLoadCatalog.legPress.id ? "slp" : seatedExtensionIsometricId
            default:
                presetID = option.hsrPresetID
            }
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
        let injuryID = PrimaryLoadCatalog.option(for: primaryLoadID).injuryID
        if injuryID == InjuryCatalog.patellarTendinopathy.id {
            return TwelveWeekPlan.presetIDs(for: phase).compactMap { id in
                all.first { $0.id == id }
            }
        }
        let filtered = all.enumerated().filter { _, preset in
            guard preset.injuryID == injuryID else { return false }
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
