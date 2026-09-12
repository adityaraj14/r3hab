import Foundation

/// The one injury R3hab ships: jumper’s knee / patellar tendinopathy.
/// Older stored ids (knee aliases and the retired QL strain template) remap to
/// it so existing installs and backups keep working without a second track.
struct InjuryDefinition: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var subtitle: String
}

enum InjuryCatalog {
    /// Retired ids. Stored values remap to `patellar-tendinopathy` on launch.
    static let retiredIDs: Set<String> = [
        "jumpers-knee",
        "patellar-tendonitis",
        "ql-strain"
    ]

    static let patellarTendinopathy = InjuryDefinition(
        id: "patellar-tendinopathy",
        title: "Jumper’s knee / patellar tendinopathy",
        subtitle: "Also called patellar tendonitis · one knee protocol."
    )

    static let all: [InjuryDefinition] = [patellarTendinopathy]
    static let defaultSelectable = patellarTendinopathy

    /// Protocol identity shown in the Phase guide and Session editor header.
    static let protocolName = "Patellar tendinopathy"
    static let protocolDescription = "Progressive loading A→E, pain-guided 24h decisions, one primary lift (default seated leg extension)."
    static let systemImage = "figure.strengthtraining.traditional"

    static func remappedID(_ id: String) -> String {
        retiredIDs.contains(id) ? patellarTendinopathy.id : id
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
