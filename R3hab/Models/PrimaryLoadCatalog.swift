import Foundation

/// The user’s chosen primary tendon-loading lift. Default is seated leg extension.
struct PrimaryLoadOption: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    /// SessionPreset id used in Phase A/B (isometrics).
    var isometricPresetID: String
    /// SessionPreset id used from Phase C onward (HSR / strength).
    var hsrPresetID: String
    var logCTA: String
    var homeObjective: String
}

enum PrimaryLoadCatalog {
    static let seatedExtension = PrimaryLoadOption(
        id: "seated-extension",
        title: "Seated leg extension",
        subtitle: "Default · iso holds, then heavy slow on the machine",
        isometricPresetID: "ext",
        hsrPresetID: "ke",
        logCTA: "Log seated extension",
        homeObjective: "Primary load is seated leg extension. Build tendon capacity without next-morning flares."
    )

    static let spanishSquat = PrimaryLoadOption(
        id: "spanish-squat",
        title: "Spanish squat",
        subtitle: "Band behind the knees · no extension machine needed",
        isometricPresetID: "spanish",
        hsrPresetID: "spanish",
        logCTA: "Log Spanish squat",
        homeObjective: "Primary load is Spanish squat. Build tendon capacity without next-morning flares."
    )

    static let wallSit = PrimaryLoadOption(
        id: "wall-sit",
        title: "Wall sit",
        subtitle: "No equipment now · seated HSR when you reach Phase C",
        isometricPresetID: "wall",
        hsrPresetID: "ke",
        logCTA: "Log wall sit",
        homeObjective: "Primary load is wall sit (seated HSR in Phase C). Build tendon capacity without next-morning flares."
    )

    static let legPress = PrimaryLoadOption(
        id: "leg-press",
        title: "Leg press",
        subtitle: "HSR on the press · seated-extension holds in Phase B",
        isometricPresetID: "ext",
        hsrPresetID: "lp",
        logCTA: "Log leg press",
        homeObjective: "Primary load is leg press (seated-extension holds in Phase B). Build tendon capacity without next-morning flares."
    )

    static let all: [PrimaryLoadOption] = [
        seatedExtension,
        spanishSquat,
        wallSit,
        legPress
    ]

    static let defaultSelectable = seatedExtension
    static let defaultID = seatedExtension.id

    static func option(for id: String) -> PrimaryLoadOption {
        all.first { $0.id == id } ?? defaultSelectable
    }

    static func normalizedID(_ id: String) -> String {
        option(for: id).id
    }

    static func presetIDs(for id: String) -> Set<String> {
        let option = option(for: id)
        return [option.isometricPresetID, option.hsrPresetID]
    }
}
