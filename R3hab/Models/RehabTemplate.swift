import Foundation

/// A rehab “issue” the user is actively managing (e.g. knee tendon + low back / QL).
enum RehabTrackID: String, Codable, CaseIterable, Identifiable, Sendable {
    case knee
    case lowerBack

    var id: String { rawValue }

    var title: String {
        switch self {
        case .knee: return "Knee"
        case .lowerBack: return "Low back"
        }
    }

    var subtitle: String {
        switch self {
        case .knee: return "Patellar tendon"
        case .lowerBack: return "QL / side-bend capacity"
        }
    }

    var loadRegion: LoadRegion {
        switch self {
        case .knee: return .knee
        case .lowerBack: return .lowerBack
        }
    }

    var systemImage: String {
        switch self {
        case .knee: return "figure.strengthtraining.traditional"
        case .lowerBack: return "figure.core.training"
        }
    }
}

/// Static template catalog. Both can be active at once (stored on AppSettings).
struct RehabTemplate: Identifiable, Hashable, Sendable {
    var id: RehabTrackID
    var name: String
    var shortDescription: String
    /// One-line objective for Home.
    var objective80_20: String

    static let knee = RehabTemplate(
        id: .knee,
        name: "Knee · patellar tendon",
        shortDescription: "Progressive loading A→E, pain-guided 24h decisions, leg extension iso/HSR.",
        objective80_20: "Build tendon capacity without next-morning flares; track load per set."
    )

    static let lowerBack = RehabTemplate(
        id: .lowerBack,
        name: "Low back · QL / trunk",
        shortDescription: "Side-bend + extension capacity; side plank / suitcase + hip thrust; walk.",
        objective80_20: "2–3×/week trunk holds + hip thrust; walk most days; soft-cut if next-day back is worse."
    )

    static let all: [RehabTemplate] = [.knee, .lowerBack]

    static func template(for id: RehabTrackID) -> RehabTemplate {
        all.first { $0.id == id } ?? .knee
    }
}
