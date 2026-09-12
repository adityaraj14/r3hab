import Foundation

/// The user’s chosen primary loading movement. Knee default is seated extension.
struct PrimaryLoadOption: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    var track: RehabTrackID
    /// SessionPreset id used in Phase A/B (isometrics / easy variant).
    var isometricPresetID: String
    /// SessionPreset id used from Phase C onward (HSR / strength). Walking reuses the same id.
    var hsrPresetID: String
    var logCTA: String
    var homeObjective: String
    /// False for walking — Progress must not invent lbs.
    var plotsLoad: Bool

    var chartLoadTitle: String {
        if !plotsLoad { return title }
        return id == "seated-extension" ? "Seated extension load" : "\(title) load"
    }
}

enum PrimaryLoadCatalog {
    /// Retired knee primaries. Existing settings / backups remap to seated extension.
    static let retiredKneeIDs: Set<String> = ["spanish-squat", "wall-sit"]

    static let seatedExtension = PrimaryLoadOption(
        id: "seated-extension",
        title: "Seated extension",
        subtitle: "Default · iso holds, then heavy slow on the machine",
        track: .knee,
        isometricPresetID: "ext",
        hsrPresetID: "ke",
        logCTA: "Log seated extension",
        homeObjective: "Primary load is seated extension. Build tendon capacity without next-morning flares.",
        plotsLoad: true
    )

    static let legPress = PrimaryLoadOption(
        id: "leg-press",
        title: "Leg press",
        subtitle: "Same load logger as seated extension · holds, then heavy slow",
        track: .knee,
        isometricPresetID: "lp-iso",
        hsrPresetID: "lp",
        logCTA: "Log leg press",
        homeObjective: "Primary load is leg press. Build tendon capacity without next-morning flares.",
        plotsLoad: true
    )

    static let hipThrust = PrimaryLoadOption(
        id: "ql-hip-thrust",
        title: "Hip thrusts",
        subtitle: "Default QL load · glute bridge / bar or bodyweight",
        track: .ql,
        isometricPresetID: "ql-ht",
        hsrPresetID: "ql-ht",
        logCTA: "Log hip thrusts",
        homeObjective: "Primary load is hip thrusts. Side bends and walking stay in the same QL template.",
        plotsLoad: true
    )

    static let standingSideBend = PrimaryLoadOption(
        id: "ql-side-bend",
        title: "Standing side bends",
        subtitle: "Lateral trunk / abdomen · dumbbell or bodyweight",
        track: .ql,
        isometricPresetID: "ql-sb",
        hsrPresetID: "ql-sb",
        logCTA: "Log side bends",
        homeObjective: "Primary work is standing side bends. Hip thrusts load; walking stays easy.",
        plotsLoad: true
    )

    static let walking = PrimaryLoadOption(
        id: "ql-walk",
        title: "Walking",
        subtitle: "Time and steps — not a loaded lift. Does not count toward the 48h chain.",
        track: .ql,
        isometricPresetID: "ql-walk",
        hsrPresetID: "ql-walk",
        logCTA: "Log walk",
        homeObjective: "Walking is the easy vote. Hip thrusts and side bends carry the load; don’t invent lbs on a walk.",
        plotsLoad: false
    )

    static let all: [PrimaryLoadOption] = [
        seatedExtension,
        legPress,
        hipThrust,
        standingSideBend,
        walking
    ]

    static let defaultSelectable = seatedExtension
    static let defaultID = seatedExtension.id

    static func options(for track: RehabTrackID) -> [PrimaryLoadOption] {
        all.filter { $0.track == track }
    }

    static func defaultSelectable(for track: RehabTrackID) -> PrimaryLoadOption {
        switch track {
        case .knee: return seatedExtension
        case .ql: return hipThrust
        }
    }

    static func defaultID(for track: RehabTrackID) -> String {
        defaultSelectable(for: track).id
    }

    static func option(for id: String, track: RehabTrackID? = nil) -> PrimaryLoadOption {
        let resolved = remappedID(id)
        if let match = all.first(where: { $0.id == resolved }) {
            if let track, match.track != track {
                return defaultSelectable(for: track)
            }
            return match
        }
        return defaultSelectable(for: track ?? .knee)
    }

    static func normalizedID(_ id: String, track: RehabTrackID? = nil) -> String {
        option(for: id, track: track).id
    }

    /// True when a stored id is retired or unknown and should be rewritten once.
    static func needsRemap(_ id: String, track: RehabTrackID? = nil) -> Bool {
        normalizedID(id, track: track) != id
    }

    static func remappedID(_ id: String) -> String {
        retiredKneeIDs.contains(id) ? seatedExtension.id : id
    }

    static func contains(_ id: String, on track: RehabTrackID) -> Bool {
        all.contains { $0.id == id && $0.track == track }
    }

    static func presetIDs(for id: String) -> Set<String> {
        let option = option(for: id)
        return [option.isometricPresetID, option.hsrPresetID]
    }
}
