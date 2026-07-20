import Foundation

extension DailyCheckIn {
    var snapshot: DailyCheckInSnapshot {
        DailyCheckInSnapshot(date: date, restingPainAM: restingPainAM, steps: steps)
    }
}

extension TrainingSession {
    var snapshot: TrainingSessionSnapshot {
        TrainingSessionSnapshot(
            id: id,
            date: date,
            createdAt: createdAt,
            sessionType: sessionType,
            response24h: response24h,
            decision: decision,
            resolvedAt: resolvedAt,
            snoozedUntil: snoozedUntil,
            phase: phase
        )
    }
}

extension AppSettings {
    var phaseSnapshot: PhaseSettingsSnapshot {
        PhaseSettingsSnapshot(
            currentPhase: currentPhase,
            phaseChangedAt: phaseChangedAt,
            phaseAPainThreshold: phaseAPainThreshold,
            phaseAStableDaysRequired: phaseAStableDaysRequired,
            stepNearNormalMin: stepNearNormalMin,
            amReminderHour: amReminderHour,
            amReminderMinute: amReminderMinute
        )
    }
}
