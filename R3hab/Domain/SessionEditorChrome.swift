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

    var showsDelete: Bool { self == .historical }

    var shows24hResolution: Bool { self == .historical }

    /// After left the session form. Capture stays on Today / AfterPainSheet.
    var showsAfterPain: Bool { false }

    /// New logs and open drafts may save a draft. Historical edits may not.
    /// The button stays hidden until the form differs from its loaded baseline.
    var showsDraftSave: Bool { self != .historical }

    var usesNewSessionChrome: Bool { self != .historical }
}

/// Fields the log form can save as a draft. Set ids are dropped so a rebuilt
/// pair with the same reps, load, and side is still the saved state.
struct SessionDraftFields: Equatable, Sendable {
    struct SetContent: Equatable, Sendable {
        var reps: Int?
        var loadLbs: Double?
        var holdSeconds: Int?
        var isWarmup: Bool
        var side: KneeSide?
        var painDuring: Int?
        var steps: Int?
        var durationMinutes: Int?

        init(_ set: ResistanceSet) {
            reps = set.reps
            loadLbs = set.loadLbs
            holdSeconds = set.holdSeconds
            isWarmup = set.isWarmup
            side = set.side
            painDuring = set.painDuring
            steps = set.steps
            durationMinutes = set.durationMinutes
        }
    }

    var phase: RehabPhase
    var sessionType: SessionType
    var whatIDid: String
    var notes: String
    var painDuring: Int?
    var sets: [SetContent]

    /// Visible only while this editor can save a draft and the form is not
    /// the pristine seed or the last saved draft.
    static func showsSaveDraft(kind: SessionEditorKind, current: Self, baseline: Self) -> Bool {
        kind.showsDraftSave && current != baseline
    }
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
