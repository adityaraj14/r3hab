import Foundation

/// A selectable rehab diary. Patellar tendinopathy is the original path.
/// QL strain is a second logging path — not a copy of the knee loading ladder.
struct InjuryDefinition: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var protocolName: String
    var protocolDescription: String
    var systemImage: String
}

enum InjuryCatalog {
    /// Knee aliases only. `ql-strain` is selectable again and must not remap.
    static let retiredIDs: Set<String> = [
        "jumpers-knee",
        "patellar-tendonitis"
    ]

    static let patellarTendinopathy = InjuryDefinition(
        id: "patellar-tendinopathy",
        title: "Jumper’s knee / patellar tendinopathy / patellar tendonitis",
        protocolName: "Patellar tendinopathy",
        protocolDescription: "Progressive loading A→C, pain-guided 24h decisions, one primary lift (default seated leg extension).",
        systemImage: "figure.strengthtraining.traditional"
    )

    static let qlStrain = InjuryDefinition(
        id: "ql-strain",
        title: "QL strain",
        protocolName: "QL strain",
        protocolDescription: "Log walking, weighted side bends, and hip thrusts. Clinical loads are TBD — this is a diary, not a copied tendon protocol.",
        systemImage: "figure.walk"
    )

    static let all: [InjuryDefinition] = [patellarTendinopathy, qlStrain]
    /// Fresh installs and unknown ids stay on the original knee diary.
    static let defaultSelectable = patellarTendinopathy

    static var protocolName: String { patellarTendinopathy.protocolName }
    static var protocolDescription: String { patellarTendinopathy.protocolDescription }
    static var systemImage: String { patellarTendinopathy.systemImage }

    static func isPatellar(_ id: String) -> Bool {
        normalizedID(id) == patellarTendinopathy.id
    }

    static func isQL(_ id: String) -> Bool {
        normalizedID(id) == qlStrain.id
    }

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
