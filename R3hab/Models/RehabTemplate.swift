import Foundation

enum RehabTrackID: String, Codable, CaseIterable, Identifiable, Sendable {
    case knee
    case ql

    var id: String { rawValue }

    var title: String {
        switch self {
        case .knee: return "Knee"
        case .ql: return "QL"
        }
    }

    var subtitle: String {
        switch self {
        case .knee: return "Patellar tendon"
        case .ql: return "Quadratus lumborum"
        }
    }

    var loadRegion: LoadRegion {
        switch self {
        case .knee: return .knee
        case .ql: return .ql
        }
    }

    var systemImage: String {
        switch self {
        case .knee: return "figure.strengthtraining.traditional"
        case .ql: return "figure.strengthtraining.functional"
        }
    }

    var lateralityNoun: String {
        switch self {
        case .knee: return "knees"
        case .ql: return "sides"
        }
    }
}

struct RehabTemplate: Identifiable, Hashable, Sendable {
    var id: RehabTrackID
    var name: String
    var shortDescription: String
    var objective80_20: String

    static let knee = RehabTemplate(
        id: .knee,
        name: "Patellar tendinopathy",
        shortDescription: "Progressive loading A→E, pain-guided 24h decisions, one primary lift (default seated leg extension).",
        objective80_20: PrimaryLoadCatalog.defaultSelectable.homeObjective
    )

    static let ql = RehabTemplate(
        id: .ql,
        name: "QL strain",
        shortDescription: "Focused quadratus lumborum template: hip thrusts, standing side bends, and walking. Judge by the next morning.",
        objective80_20: PrimaryLoadCatalog.hipThrust.homeObjective
    )

    func objective(for primaryLoad: PrimaryLoadOption) -> String {
        primaryLoad.homeObjective
    }

    static let all: [RehabTemplate] = [.knee, .ql]

    static func template(for id: RehabTrackID) -> RehabTemplate {
        all.first { $0.id == id } ?? .knee
    }
}
