import Foundation
import SwiftData

struct SessionPrototypeSaveError: Error, Equatable {
    var message: String
}

/// New finalized log. Same validation, pain copy, insert, and reminders as SessionEditor.
@MainActor
enum SessionPrototypeSave {
    static func commit(
        draft: SessionPrototypeDraft,
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
            throw SessionPrototypeSaveError(message: issue.message)
        }
        let storedDuring = draft.painDuring ?? PainScore.notLogged
        let row = TrainingSession(
            date: date,
            phase: draft.phase,
            sessionType: draft.sessionType,
            whatIDid: text,
            painDuring: storedDuring,
            painAfter: PainScore.notLogged,
            resistanceSets: sets,
            calendar: calendar
        )
        row.notes = draft.notes
        row.isDraft = false
        context.insert(row)
        do {
            try context.save()
        } catch {
            throw SessionPrototypeSaveError(message: error.localizedDescription)
        }
        schedule(row, settings: settings)
    }

    private static func schedule(_ session: TrainingSession, settings: AppSettings?) {
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
}
