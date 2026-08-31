import Foundation

/// One onboarding injury label and the protocol it currently runs.
/// Add a new row to `InjuryCatalog.all` when a new protocol ships — OnboardingView
/// only iterates `selectable`, so the first screen does not need a rewrite.
struct InjuryDefinition: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    /// Protocol this label maps to. All current options use the knee / PT diary.
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

    /// Registry for current and future injuries. Keep QL / low-back out until a protocol exists.
    static let all: [InjuryDefinition] = [
        jumpersKnee,
        patellarTendinopathy,
        patellarTendonitis
    ]

    static var selectable: [InjuryDefinition] {
        all.filter(\.isSelectable)
    }

    static let defaultSelectable = patellarTendinopathy

    static func definition(for id: String) -> InjuryDefinition {
        all.first { $0.id == id } ?? defaultSelectable
    }

    static func normalizedID(_ id: String) -> String {
        definition(for: id).id
    }
}
