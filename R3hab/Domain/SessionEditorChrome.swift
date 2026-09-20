import Foundation

enum SessionEditorKind: Equatable, Sendable {
    case newLog
    case draft
    case historical

    /// `nil` existing row is a new log. A loaded row is draft or historical.
    static func classify(existingIsDraft: Bool?) -> SessionEditorKind {
        switch existingIsDraft {
        case nil: return .newLog
        case .some(true): return .draft
        case .some(false): return .historical
        }
    }

    /// Saved non-draft sessions can be deleted from the editor.
    var showsDelete: Bool { self == .historical }

    /// Next-morning Better / Same / Worse. Drafts and new logs stay off this UI.
    var shows24hResolution: Bool { self == .historical }

    /// After-pain left the session form. Capture stays on Today / AfterPainSheet.
    var showsAfterPain: Bool { false }

    var showsDraftSave: Bool { self != .historical }

    var usesNewSessionChrome: Bool { self != .historical }
}

enum Session24hResolution: Equatable, Sendable {
    /// Pain-pane choices. Pending and Rest stay representable as no selection.
    static func pickerSelection(stored: Response24h) -> Response24h? {
        switch stored {
        case .better, .same, .worse:
            return stored
        case .pending, .notApplicable:
            return nil
        }
    }

    struct Write: Equatable, Sendable {
        var response: Response24h
        var decision: SessionDecision?
        var resolvedAt: Date?
        var snoozedUntil: Date?
        var cancelsPendingNotification: Bool
    }

    /// Overwrite `response24h` / `decision` the same way Resolve24hSheet does.
    /// A nil or unchanged picker leaves the stored row alone.
    static func write(
        selected: Response24h?,
        storedResponse: Response24h,
        storedDecision: SessionDecision?,
        storedResolvedAt: Date?,
        storedSnoozedUntil: Date?,
        suggestedDecision: SessionDecision?,
        now: Date
    ) -> Write {
        let unchanged = Write(
            response: storedResponse,
            decision: storedDecision,
            resolvedAt: storedResolvedAt,
            snoozedUntil: storedSnoozedUntil,
            cancelsPendingNotification: false
        )
        guard let selected else { return unchanged }
        switch selected {
        case .pending, .notApplicable:
            return unchanged
        case .better, .same, .worse:
            if selected == storedResponse { return unchanged }
            return Write(
                response: selected,
                decision: suggestedDecision,
                resolvedAt: now,
                snoozedUntil: nil,
                cancelsPendingNotification: true
            )
        }
    }
}
