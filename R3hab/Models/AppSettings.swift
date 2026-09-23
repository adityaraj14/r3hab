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
    /// Unused since the QL track was removed. Kept for SwiftData schema stability.
    var activeTracksCSV: String = "knee"
    /// Unused. Kept for SwiftData schema stability.
    var backTrackStageRaw: String = ""
    /// Injury id from `InjuryCatalog`. Retired ids (incl. `ql-strain`) remap on launch.
    var selectedInjuryID: String = "patellar-tendinopathy"
    /// Primary movement from `PrimaryLoadCatalog`. Default is seated leg extension.
    var primaryLoadID: String = "seated-extension"

    var currentPhase: RehabPhase {
        get { RehabPhase.normalized(rawValue: currentPhaseRaw) }
        set {
            currentPhaseRaw = newValue.rawValue
            phaseChangedAt = Date()
        }
    }

    var selectedInjury: InjuryDefinition {
        get { InjuryCatalog.definition(for: selectedInjuryID) }
        set { selectedInjuryID = newValue.id }
    }

    var primaryLoad: PrimaryLoadOption {
        get { PrimaryLoadCatalog.option(for: primaryLoadID) }
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
        self.activeTracksCSV = "knee"
        self.backTrackStageRaw = ""
        self.selectedInjuryID = InjuryCatalog.defaultSelectable.id
        self.primaryLoadID = PrimaryLoadCatalog.defaultID
    }
}
