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
    /// Comma-separated `RehabTrackID` raw values, e.g. `"knee,lowerBack"`.
    var activeTracksCSV: String = "knee,lowerBack"
    /// Back track stage: irritable | iso | dynamic | maintain
    var backTrackStageRaw: String = "iso"

    var currentPhase: RehabPhase {
        get { RehabPhase(rawValue: currentPhaseRaw) ?? .aFlareDeLoad }
        set {
            currentPhaseRaw = newValue.rawValue
            phaseChangedAt = Date()
        }
    }

    var activeTracks: [RehabTrackID] {
        get {
            let parts = activeTracksCSV.split(separator: ",").map(String.init)
            let parsed = parts.compactMap { RehabTrackID(rawValue: $0) }
            return parsed.isEmpty ? [.knee, .lowerBack] : parsed
        }
        set {
            let unique = RehabTrackID.allCases.filter { newValue.contains($0) }
            activeTracksCSV = (unique.isEmpty ? [.knee] : unique).map(\.rawValue).joined(separator: ",")
        }
    }

    var isKneeTrackActive: Bool { activeTracks.contains(.knee) }
    var isBackTrackActive: Bool { activeTracks.contains(.lowerBack) }

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
        self.activeTracksCSV = "knee,lowerBack"
        self.backTrackStageRaw = "iso"
    }
}
