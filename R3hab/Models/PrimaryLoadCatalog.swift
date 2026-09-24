import Foundation

/// The user’s chosen primary loading movement. Knee only: seated leg extension
/// (default) or leg press.
struct PrimaryLoadOption: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    /// SessionPreset id used in Phase A/B (isometrics / easy variant).
    var isometricPresetID: String
    /// SessionPreset id used from Phase C onward (HSR / strength).
    var hsrPresetID: String
    var logCTA: String
    var homeObjective: String

    var chartVolumeTitle: String {
        "\(title) volume"
    }

    /// Phrases that identify this lift in free-text `whatIDid`.
    /// Seated leg extension also accepts the pre-rename short name.
    var historyMatchPhrases: [String] {
        if id == "seated-extension" {
            return [title, PrimaryLoadCatalog.legacySeatedExtensionDisplayName]
        }
        return [title]
    }

    func nextUpCTA(hasDraft: Bool) -> String {
        hasDraft ? "Resume \(title.lowercased())" : logCTA
    }
}

enum PrimaryLoadCatalog {
    /// Retired ids (old knee primaries and the removed QL template). Existing
    /// settings / backups remap to seated leg extension.
    static let retiredIDs: Set<String> = [
        "spanish-squat",
        "wall-sit",
        "ql-hip-thrust",
        "ql-side-bend",
        "ql-walk"
    ]

    /// Display string stored in `whatIDid` before this lift was renamed.
    /// History matching still accepts it. Not a current label.
    static let legacySeatedExtensionDisplayName = "Seated extension"

    static let seatedExtension = PrimaryLoadOption(
        id: "seated-extension",
        title: "Seated leg extension",
        subtitle: "Default · iso holds, then heavy slow on the machine",
        isometricPresetID: "ext",
        hsrPresetID: "ke",
        logCTA: "Log Workout",
        homeObjective: "Primary load is seated leg extension. Build tendon capacity without next-morning flares."
    )

    static let legPress = PrimaryLoadOption(
        id: "leg-press",
        title: "Leg press",
        subtitle: "Same load logger as seated leg extension · holds, then heavy slow",
        isometricPresetID: "lp-iso",
        hsrPresetID: "lp",
        logCTA: "Log leg press",
        homeObjective: "Primary load is leg press. Build tendon capacity without next-morning flares."
    )

    static let all: [PrimaryLoadOption] = [seatedExtension, legPress]

    static let defaultSelectable = seatedExtension
    static let defaultID = seatedExtension.id

    static func option(for id: String) -> PrimaryLoadOption {
        let resolved = remappedID(id)
        return all.first { $0.id == resolved } ?? defaultSelectable
    }

    static func normalizedID(_ id: String) -> String {
        option(for: id).id
    }

    /// True when a stored id is retired or unknown and should be rewritten once.
    static func needsRemap(_ id: String) -> Bool {
        normalizedID(id) != id
    }

    static func remappedID(_ id: String) -> String {
        retiredIDs.contains(id) ? seatedExtension.id : id
    }

    static func contains(_ id: String) -> Bool {
        all.contains { $0.id == id }
    }

    static func presetIDs(for id: String) -> Set<String> {
        let option = option(for: id)
        return [option.isometricPresetID, option.hsrPresetID]
    }
}
