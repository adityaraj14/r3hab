enum History24hSwipe: Equatable, Sendable {
    case resolve
    case edit

    var title: String {
        switch self {
        case .resolve: return "Resolve"
        case .edit: return "Edit 24h"
        }
    }

    static func action(isDraft: Bool, response24h: Response24h) -> History24hSwipe? {
        guard !isDraft else { return nil }
        return response24h == .pending ? .resolve : .edit
    }
}
