import Foundation

/// How a primary modality is logged. Knee lifts use the existing ladder.
/// QL modalities are logging-first. Clinical targets for QL are TBD.
enum PrimaryLoadLogging: Equatable, Hashable, Sendable {
    case kneeLadder
    /// Load + reps. `allowsSides` is the side-bend L/R split.
    case weightedReps(allowsSides: Bool)
    case walk
}

/// The user’s chosen primary movement, scoped to one injury.
struct PrimaryLoadOption: Identifiable, Hashable, Sendable {
    var id: String
    var injuryID: String
    var title: String
    var subtitle: String
    /// SessionPreset id used in Phase A/B (isometrics / easy variant).
    var isometricPresetID: String
    /// SessionPreset id used from Phase C onward (HSR / strength).
    /// QL modalities use the same preset for both — there is no knee ladder.
    var hsrPresetID: String
    var logCTA: String
    var homeObjective: String
    var logging: PrimaryLoadLogging

    var usesPatellarLadder: Bool {
        if case .kneeLadder = logging { return true }
        return false
    }

    var isWalk: Bool {
        if case .walk = logging { return true }
        return false
    }

    var allowsSideSplit: Bool {
        if case .weightedReps(let allowsSides) = logging { return allowsSides }
        return false
    }

    /// Phrases that identify this movement in free-text `whatIDid`.
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
    /// Retired knee primaries only. QL ids are live again and must not remap
    /// onto seated leg extension.
    static let retiredIDs: Set<String> = [
        "spanish-squat",
        "wall-sit"
    ]

    /// Display string stored in `whatIDid` before this lift was renamed.
    /// History matching still accepts it. Not a current label.
    static let legacySeatedExtensionDisplayName = "Seated extension"

    static let seatedExtension = PrimaryLoadOption(
        id: "seated-extension",
        injuryID: "patellar-tendinopathy",
        title: "Seated leg extension",
        subtitle: "Default · iso holds, then heavy slow on the machine",
        isometricPresetID: "ext",
        hsrPresetID: "ke",
        logCTA: "Log Workout",
        homeObjective: "Primary load is seated leg extension. Build tendon capacity without next-morning flares.",
        logging: .kneeLadder
    )

    static let legPress = PrimaryLoadOption(
        id: "leg-press",
        injuryID: "patellar-tendinopathy",
        title: "Leg press",
        subtitle: "Same load logger as seated leg extension · holds, then heavy slow",
        isometricPresetID: "lp-iso",
        hsrPresetID: "lp",
        logCTA: "Log leg press",
        homeObjective: "Primary load is leg press. Build tendon capacity without next-morning flares.",
        logging: .kneeLadder
    )

    static let qlWalk = PrimaryLoadOption(
        id: "ql-walk",
        injuryID: "ql-strain",
        title: "Walking",
        subtitle: "Steps, or time. The step number is a reminder, not a protocol.",
        isometricPresetID: "ql-walk",
        hsrPresetID: "ql-walk",
        logCTA: "Log walk",
        homeObjective: "Primary is walking. Log steps or time. Clinical step targets are TBD.",
        logging: .walk
    )

    static let qlSideBend = PrimaryLoadOption(
        id: "ql-side-bend",
        injuryID: "ql-strain",
        title: "Side bend",
        subtitle: "Some weight · reps, optional left and right",
        isometricPresetID: "ql-side-bend",
        hsrPresetID: "ql-side-bend",
        logCTA: "Log side bend",
        homeObjective: "Primary is weighted side bends. Log the load you used. Clinical targets are TBD.",
        logging: .weightedReps(allowsSides: true)
    )

    static let qlHipThrust = PrimaryLoadOption(
        id: "ql-hip-thrust",
        injuryID: "ql-strain",
        title: "Hip thrust",
        subtitle: "Load and reps. Last weight prefills the next log.",
        isometricPresetID: "ql-hip-thrust",
        hsrPresetID: "ql-hip-thrust",
        logCTA: "Log hip thrust",
        homeObjective: "Primary is hip thrusts. Log load and reps. Clinical targets are TBD.",
        logging: .weightedReps(allowsSides: false)
    )

    static let all: [PrimaryLoadOption] = [
        seatedExtension,
        legPress,
        qlWalk,
        qlSideBend,
        qlHipThrust
    ]

    static let defaultSelectable = seatedExtension
    static let defaultID = seatedExtension.id
    /// Blank QL diary starts on walking — the first modality Adi named.
    static let qlDefaultID = qlWalk.id

    static func options(for injuryID: String) -> [PrimaryLoadOption] {
        let resolved = InjuryCatalog.normalizedID(injuryID)
        let matches = all.filter { $0.injuryID == resolved }
        return matches.isEmpty ? [defaultSelectable] : matches
    }

    static func defaultID(for injuryID: String) -> String {
        InjuryCatalog.isQL(injuryID) ? qlDefaultID : defaultID
    }

    /// Live id, including a QL modality. Retired knee ids become seated extension.
    /// Unknown ids become seated extension so old unscoped call sites stay knee-safe.
    static func option(for id: String) -> PrimaryLoadOption {
        if let match = all.first(where: { $0.id == id }) { return match }
        let resolved = remappedID(id)
        return all.first { $0.id == resolved } ?? defaultSelectable
    }

    /// Option that belongs to this injury. A knee lift stored on a QL profile
    /// (and the reverse) falls back to that injury’s default.
    static func option(for id: String, injuryID: String) -> PrimaryLoadOption {
        let resolved = normalizedID(id, injuryID: injuryID)
        return all.first { $0.id == resolved } ?? option(for: defaultID(for: injuryID))
    }

    static func normalizedID(_ id: String) -> String {
        if all.contains(where: { $0.id == id }) { return id }
        if retiredIDs.contains(id) { return seatedExtension.id }
        return defaultID
    }

    static func normalizedID(_ id: String, injuryID: String) -> String {
        let allowed = options(for: injuryID)
        if allowed.contains(where: { $0.id == id }) { return id }
        return defaultID(for: injuryID)
    }

    /// True when a stored id is retired or unknown and should be rewritten once.
    /// Live QL ids are not a remap. Cross-injury mismatches use `needsRemap(_:injuryID:)`.
    static func needsRemap(_ id: String) -> Bool {
        normalizedID(id) != id
    }

    static func needsRemap(_ id: String, injuryID: String) -> Bool {
        normalizedID(id, injuryID: injuryID) != id
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
