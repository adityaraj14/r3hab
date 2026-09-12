import Foundation

/// One onboarding injury label and the protocol it currently runs.
/// Onboarding and Settings pickers iterate `selectable` (two rows). Older knee
/// aliases stay in `all` so existing installs remap without losing the track.
struct InjuryDefinition: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    var protocolTrack: RehabTrackID
    var isSelectable: Bool
}

enum InjuryCatalog {
    /// Retired onboarding rows. Stored ids remap to `patellar-tendinopathy`.
    static let collapsedKneeAliasIDs: Set<String> = [
        "jumpers-knee",
        "patellar-tendonitis"
    ]

    static let jumpersKnee = InjuryDefinition(
        id: "jumpers-knee",
        title: "Jumper's knee",
        subtitle: "Patellar tendon · pain-guided loading",
        protocolTrack: .knee,
        isSelectable: false
    )

    static let patellarTendinopathy = InjuryDefinition(
        id: "patellar-tendinopathy",
        title: "Jumper’s knee / patellar tendinopathy",
        subtitle: "Also called patellar tendonitis · same knee protocol.",
        protocolTrack: .knee,
        isSelectable: true
    )

    static let patellarTendonitis = InjuryDefinition(
        id: "patellar-tendonitis",
        title: "Patellar tendonitis",
        subtitle: "Same knee protocol as patellar tendinopathy",
        protocolTrack: .knee,
        isSelectable: false
    )

    static let qlStrain = InjuryDefinition(
        id: "ql-strain",
        title: "QL strain",
        subtitle: "Side-of-waist · hip thrusts, side bends, walking.",
        protocolTrack: .ql,
        isSelectable: true
    )

    static let all: [InjuryDefinition] = [
        jumpersKnee,
        patellarTendinopathy,
        patellarTendonitis,
        qlStrain
    ]

    static var selectable: [InjuryDefinition] {
        all.filter(\.isSelectable)
    }

    /// Skip-from-the-first-screen default stays the knee diary.
    static let defaultSelectable = patellarTendinopathy

    static func remappedID(_ id: String) -> String {
        collapsedKneeAliasIDs.contains(id) ? patellarTendinopathy.id : id
    }

    static func definition(for id: String) -> InjuryDefinition {
        let resolved = remappedID(id)
        return all.first { $0.id == resolved } ?? defaultSelectable
    }

    static func normalizedID(_ id: String) -> String {
        definition(for: id).id
    }

    static func needsRemap(_ id: String) -> Bool {
        normalizedID(id) != id
    }

    static func contains(_ id: String) -> Bool {
        all.contains { $0.id == id }
    }
}
