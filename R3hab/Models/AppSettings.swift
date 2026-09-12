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
    /// Stored track id (`knee` or `ql`). Leftover dual-track CSV is migrated once.
    var activeTracksCSV: String = "knee"
    /// Unused. Kept for SwiftData schema stability.
    var backTrackStageRaw: String = ""
    /// Onboarding injury id from `InjuryCatalog`. Default is lightweight-migration safe.
    var selectedInjuryID: String = "patellar-tendinopathy"
    /// Primary movement from `PrimaryLoadCatalog`. Default is seated leg extension (knee).
    var primaryLoadID: String = "seated-extension"

    var currentPhase: RehabPhase {
        get { RehabPhase(rawValue: currentPhaseRaw) ?? .aFlareDeLoad }
        set {
            currentPhaseRaw = newValue.rawValue
            phaseChangedAt = Date()
        }
    }

    var activeTracks: [RehabTrackID] {
        get {
            let parsed = activeTracksCSV
                .split(separator: ",")
                .compactMap { RehabTrackID(rawValue: String($0)) }
            if parsed.isEmpty { return [protocolTrack] }
            return parsed
        }
        set {
            let tracks = newValue.isEmpty ? [protocolTrack] : newValue
            activeTracksCSV = tracks.map(\.rawValue).joined(separator: ",")
        }
    }

    var protocolTrack: RehabTrackID {
        selectedInjury.protocolTrack
    }

    var selectedInjury: InjuryDefinition {
        get { InjuryCatalog.definition(for: selectedInjuryID) }
        set {
            selectedInjuryID = newValue.id
            activeTracks = [newValue.protocolTrack]
        }
    }

    var primaryLoad: PrimaryLoadOption {
        get { PrimaryLoadCatalog.option(for: primaryLoadID, track: protocolTrack) }
        set { primaryLoadID = newValue.id }
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
        self.selectedInjuryID = InjuryCatalog.defaultSelectable.id
        self.primaryLoadID = PrimaryLoadCatalog.defaultID
    }
}
