import Foundation
import SwiftData

@Model
final class AppSettings {
    var currentPhaseRaw: String
    var phaseChangedAt: Date
    var phaseAPainThreshold: Int
    var phaseAStableDaysRequired: Int
    var stepNearNormalMin: Int
    var stepBaselineTypical: Int
    var amReminderHour: Int
    var amReminderMinute: Int
    var pmReminderHour: Int
    var pmReminderMinute: Int
    var notificationsEnabled: Bool
    var hasCompletedOnboarding: Bool
    var protocolRevision: String
    var faceIDLockEnabled: Bool
    /// Legacy dual-track CSV. Forced to knee-only; kept for SwiftData schema stability.
    var activeTracksCSV: String = "knee"
    /// Unused. Kept for SwiftData schema stability.
    var backTrackStageRaw: String = ""

    var currentPhase: RehabPhase {
        get { RehabPhase(rawValue: currentPhaseRaw) ?? .aFlareDeLoad }
        set {
            currentPhaseRaw = newValue.rawValue
            phaseChangedAt = Date()
        }
    }

    var activeTracks: [RehabTrackID] {
        get { [.knee] }
        set { activeTracksCSV = RehabTrackID.knee.rawValue }
    }

    init() {
        self.currentPhaseRaw = RehabPhase.aFlareDeLoad.rawValue
        self.phaseChangedAt = Date()
        self.phaseAPainThreshold = 2
        self.phaseAStableDaysRequired = 3
        self.stepNearNormalMin = 6000
        self.stepBaselineTypical = 7500
        self.amReminderHour = 8
        self.amReminderMinute = 0
        self.pmReminderHour = 18
        self.pmReminderMinute = 30
        self.notificationsEnabled = false
        self.hasCompletedOnboarding = false
        self.protocolRevision = "v1"
        self.faceIDLockEnabled = false
        self.activeTracksCSV = RehabTrackID.knee.rawValue
        self.backTrackStageRaw = ""
    }
}
