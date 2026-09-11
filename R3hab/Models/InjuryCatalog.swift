import Foundation

/// One onboarding injury label and the protocol it currently runs.
/// Add a new row to `InjuryCatalog.all` when a new protocol ships — OnboardingView
/// only iterates `selectable`, so the first screen does not need a rewrite.
struct InjuryDefinition: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    var protocolTrack: RehabTrackID
    var isSelectable: Bool
}

enum InjuryCatalog {
    static let jumpersKnee = InjuryDefinition(
        id: "jumpers-knee",
        title: "Jumper's knee",
        subtitle: "Patellar tendon · pain-guided loading",
        protocolTrack: .knee,
        isSelectable: true
    )

    static let patellarTendinopathy = InjuryDefinition(
        id: "patellar-tendinopathy",
        title: "Patellar tendinopathy",
        subtitle: "Same knee protocol as jumper's knee",
        protocolTrack: .knee,
        isSelectable: true
    )

    static let patellarTendonitis = InjuryDefinition(
        id: "patellar-tendonitis",
        title: "Patellar tendonitis",
        subtitle: "Same knee protocol as patellar tendinopathy",
        protocolTrack: .knee,
        isSelectable: true
    )

    static let qlStrain = InjuryDefinition(
        id: "ql-strain",
        title: "QL strain",
        subtitle: "Quadratus lumborum · side-of-waist · hip thrust / side bend / walk",
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

    static func definition(for id: String) -> InjuryDefinition {
        all.first { $0.id == id } ?? defaultSelectable
    }

    static func normalizedID(_ id: String) -> String {
        definition(for: id).id
    }

    static func contains(_ id: String) -> Bool {
        all.contains { $0.id == id }
    }
}
