import Foundation

/// The single rehab issue this app manages: patellar tendinopathy.
enum RehabTrackID: String, Codable, CaseIterable, Identifiable, Sendable {
    case knee

    var id: String { rawValue }

    var title: String { "Knee" }

    var subtitle: String { "Patellar tendon" }

    var loadRegion: LoadRegion { .knee }

    var systemImage: String { "figure.strengthtraining.traditional" }
}

/// Static template for jumper's knee (phases A–E).
struct RehabTemplate: Identifiable, Hashable, Sendable {
    var id: RehabTrackID
    var name: String
    var shortDescription: String
    /// One-line objective for Home.
    var objective80_20: String

    static let knee = RehabTemplate(
        id: .knee,
        name: "Patellar tendinopathy",
        shortDescription: "Progressive loading A→E, pain-guided 24h decisions, one primary lift (default seated leg extension).",
        objective80_20: PrimaryLoadCatalog.defaultSelectable.homeObjective
    )

    func objective(for primaryLoad: PrimaryLoadOption) -> String {
        primaryLoad.homeObjective
    }

    static let all: [RehabTemplate] = [.knee]

    static func template(for id: RehabTrackID) -> RehabTemplate {
        all.first { $0.id == id } ?? .knee
    }
}
