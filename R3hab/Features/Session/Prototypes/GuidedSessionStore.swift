import Foundation
import SwiftData

struct GuidedSaveError: Error, Equatable {
    var message: String
}

/// Writes the guided form to SwiftData. A draft and the final save use the
/// same `TrainingSession` row, so the draft becomes the session.
@MainActor
enum GuidedSessionStore {
    /// Writes the checkpoint to the draft row. Makes the row if there is none.
    /// The row is a draft from its first frame. It never gets 24h or pain-after reminders.
    @discardableResult
    static func saveDraft(
        draft: SessionPrototypeDraft,
        stepIndex: Int,
        draftId: UUID?,
        context: ModelContext,
        date: Date,
        calendar: Calendar = .current
    ) throws -> UUID {
        let checkpoint = GuidedCheckpointing.checkpoint(draft, stepIndex: stepIndex)
        let snaps = try context.fetch(FetchDescriptor<TrainingSession>()).map(\.snapshot)
        let target = SessionUpsert.target(
            preferredId: draftId,
            sessions: snaps,
            day: date,
            preferring: checkpoint.sessionType,
            calendar: calendar
        )
        let row: TrainingSession
        switch target {
        case .update(let id):
            guard let existing = try fetchRow(id: id, context: context) else {
                throw GuidedSaveError(message: "This draft is no longer available.")
            }
            row = existing
        case .insert:
            row = TrainingSession(
                date: date,
                phase: checkpoint.phase,
                sessionType: checkpoint.sessionType,
                whatIDid: checkpoint.whatIDid,
                painDuring: checkpoint.painDuring,
                isDraft: true,
                calendar: calendar
            )
            context.insert(row)
        }
        apply(checkpoint, to: row)
        row.isDraft = true
        row.guidedStepIndex = checkpoint.stepIndex
        row.updatedAt = Date()
        do {
            try context.save()
        } catch {
            throw GuidedSaveError(message: error.localizedDescription)
        }
        NotificationScheduler.cancelSessionNotifications(sessionId: row.id)
        return row.id
    }

    /// The final save. Needs the pain-during score. Converts the draft row when
    /// there is one, else makes a new row. Then the 24h and pain-after reminders start.
    static func commit(
        draft: SessionPrototypeDraft,
        draftId: UUID?,
        settings: AppSettings?,
        context: ModelContext,
        date: Date,
        calendar: Calendar = .current
    ) throws {
        let text = draft.whatIDid()
        let sets = SessionPrototypePlan.setsForSave(draft)
        if let issue = SessionSaveValidation.validate(
            painDuring: draft.painDuring,
            painAfter: nil,
            whatIDid: text,
            sets: sets
        ) {
            throw GuidedSaveError(message: issue.message)
        }
        guard let painDuring = draft.painDuring else {
            throw GuidedSaveError(message: SessionSaveIssue.missingPainDuring.message)
        }
        let snaps = try context.fetch(FetchDescriptor<TrainingSession>()).map(\.snapshot)
        let target = SessionUpsert.target(
            preferredId: draftId,
            sessions: snaps,
            day: date,
            preferring: draft.sessionType,
            calendar: calendar
        )
        let row: TrainingSession
        let isFirstFinalize: Bool
        switch target {
        case .update(let id):
            guard let existing = try fetchRow(id: id, context: context) else {
                throw GuidedSaveError(message: "This draft is no longer available.")
            }
            row = existing
            isFirstFinalize = existing.isDraft
            if isFirstFinalize {
                // The session is complete now. The pain-after reminder counts from this save.
                row.createdAt = Date()
            }
        case .insert:
            row = TrainingSession(
                date: date,
                phase: draft.phase,
                sessionType: draft.sessionType,
                whatIDid: text,
                painDuring: painDuring,
                calendar: calendar
            )
            context.insert(row)
            isFirstFinalize = true
        }
        row.phase = draft.phase
        row.sessionType = draft.sessionType
        row.whatIDid = text
        row.painDuring = painDuring
        if isFirstFinalize {
            row.painAfter = PainScore.notLogged
        }
        row.notes = draft.notes
        row.setResistanceSets(sets)
        row.isDraft = false
        row.guidedStepIndex = nil
        row.updatedAt = Date()
        do {
            try context.save()
        } catch {
            throw GuidedSaveError(message: error.localizedDescription)
        }
        if isFirstFinalize {
            schedule(row, settings: settings)
        }
    }

    private static func fetchRow(id: UUID, context: ModelContext) throws -> TrainingSession? {
        var descriptor = FetchDescriptor<TrainingSession>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func apply(_ checkpoint: GuidedCheckpoint, to row: TrainingSession) {
        row.phase = checkpoint.phase
        row.sessionType = checkpoint.sessionType
        row.whatIDid = checkpoint.whatIDid
        row.painDuring = checkpoint.painDuring
        row.notes = checkpoint.notes
        row.setResistanceSets(checkpoint.resistanceSets)
    }

    private static func schedule(_ session: TrainingSession, settings: AppSettings?) {
        guard session.isComplete else { return }
        guard let settings, settings.notificationsEnabled else { return }
        NotificationScheduler.schedulePending(
            sessionId: session.id,
            sessionDate: session.date,
            snoozedUntil: nil,
            amHour: settings.amReminderHour,
            amMinute: settings.amReminderMinute
        )
        if !session.hasLoggedPainAfter {
            NotificationScheduler.schedulePainAfter(
                sessionId: session.id,
                createdAt: session.createdAt
            )
        }
    }

    /// The draft row as a checkpoint, for resume.
    static func checkpoint(of row: TrainingSession) -> GuidedCheckpoint {
        GuidedCheckpoint(
            phase: row.phase,
            sessionType: row.sessionType,
            whatIDid: row.whatIDid,
            painDuring: row.painDuring,
            notes: row.notes,
            resistanceSets: row.resistanceSets(),
            stepIndex: row.guidedStepIndex
        )
    }
}
