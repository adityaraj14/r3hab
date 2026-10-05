import Foundation

/// One row per guided or editor save: reuse the draft for the day, never insert a second workout by accident.
enum SessionUpsert {
    /// Which row a save should write to.
    enum Target: Equatable {
        /// Update this draft (or re-save an already-finalized row from a double tap).
        case update(UUID)
        /// No matching row: insert a new one.
        case insert
    }

    /// Prefer the open draft for `day` when `preferredId` is missing or no longer a draft.
    /// If `preferredId` points at a finalized row, return `.update` so a second Save does not insert.
    static func target(
        preferredId: UUID?,
        sessions: [TrainingSessionSnapshot],
        day: Date,
        preferring type: SessionType,
        calendar: Calendar = .current
    ) -> Target {
        if let preferredId, let row = sessions.first(where: { $0.id == preferredId }) {
            if row.isDraft { return .update(preferredId) }
            // Same sheet, second tap after the first Save finalized the row.
            if calendar.isDate(row.date, inSameDayAs: day) { return .update(preferredId) }
        }
        if let draftId = SessionDraft.openDraftID(
            in: sessions,
            on: day,
            preferring: type,
            calendar: calendar
        ) {
            return .update(draftId)
        }
        return .insert
    }
}

/// Exact duplicates of one workout on the same day. Used to clean up rows from a double Save.
enum SessionDuplicate {
    struct Pair: Equatable, Sendable {
        /// Keep this row (more complete 24h response, else the earlier createdAt).
        var keepID: UUID
        /// Safe to remove: same day, same text, same sets, same pain scores.
        var removeID: UUID
    }

    /// Two finalized sessions are exact duplicates when the workout content matches.
    /// Distinct loads, pain, or notes are never treated as duplicates.
    static func isExactDuplicate(_ a: TrainingSessionSnapshot, _ b: TrainingSessionSnapshot) -> Bool {
        guard a.id != b.id else { return false }
        guard a.isFinalized && b.isFinalized else { return false }
        guard a.whatIDid == b.whatIDid else { return false }
        guard a.painDuring == b.painDuring else { return false }
        guard a.painAfter == b.painAfter else { return false }
        guard a.sessionType == b.sessionType else { return false }
        guard a.phase == b.phase else { return false }
        guard sameSets(a.resistanceSets, b.resistanceSets) else { return false }
        return true
    }

    /// Same calendar day, exact content. Keep the better-resolved row; remove the other.
    static func pairs(
        in sessions: [TrainingSessionSnapshot],
        calendar: Calendar = .current
    ) -> [Pair] {
        let finalized = SessionDraft.finalized(sessions)
        var byDay: [String: [TrainingSessionSnapshot]] = [:]
        for session in finalized {
            let key = CalendarDay.dayKey(session.date, calendar: calendar)
            byDay[key, default: []].append(session)
        }
        var result: [Pair] = []
        var removed = Set<UUID>()
        for daySessions in byDay.values {
            let sorted = daySessions.sorted { $0.createdAt < $1.createdAt }
            for i in 0..<sorted.count {
                let a = sorted[i]
                guard !removed.contains(a.id) else { continue }
                for j in (i + 1)..<sorted.count {
                    let b = sorted[j]
                    guard !removed.contains(b.id) else { continue }
                    guard isExactDuplicate(a, b) else { continue }
                    let keep = preferred(a, b)
                    let remove = keep.id == a.id ? b : a
                    result.append(Pair(keepID: keep.id, removeID: remove.id))
                    removed.insert(remove.id)
                }
            }
        }
        return result
    }

    /// Prefer a resolved 24h response over pending; else the earlier row (the first Save).
    static func preferred(_ a: TrainingSessionSnapshot, _ b: TrainingSessionSnapshot) -> TrainingSessionSnapshot {
        let aResolved = a.response24h != .pending
        let bResolved = b.response24h != .pending
        if aResolved != bResolved { return aResolved ? a : b }
        return a.createdAt <= b.createdAt ? a : b
    }

    private static func sameSets(_ a: [ResistanceSet], _ b: [ResistanceSet]) -> Bool {
        guard a.count == b.count else { return false }
        return zip(a, b).allSatisfy { lhs, rhs in
            lhs.reps == rhs.reps
                && lhs.loadLbs == rhs.loadLbs
                && lhs.holdSeconds == rhs.holdSeconds
                && lhs.isWarmup == rhs.isWarmup
                && lhs.steps == rhs.steps
                && lhs.durationMinutes == rhs.durationMinutes
        }
    }
}
