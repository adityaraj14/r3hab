import Foundation

enum PhaseGuideCopy {
    static let protocolRevision = "v1.2 · 2026-09-11"

    static func summary(
        for phase: RehabPhase,
        primaryLift: String = PrimaryLoadCatalog.defaultSelectable.title,
        injuryID: String = InjuryCatalog.patellarTendinopathy.id
    ) -> String {
        if InjuryCatalog.isQL(injuryID) {
            return qlSummary(for: phase, modality: primaryLift)
        }
        let lift = primaryLift.lowercased()
        switch phase {
        case .aFlareDeLoad:
            return "Rest the knee. Do not do a heavy knee load, impact, or tennis. You can ride a bicycle if you have no pain. Record 3 mornings with pain of 2 or less. Record one day with about 6000 steps or more. Then start Phase B."
        case .bIsometrics:
            return "The primary exercise is \(lift) holds. Start with 3 or 4 holds of 20 to 30 seconds. Do this 2 times each week. Keep at least 48 hours between sessions. Increase the hold time before you add a session day."
        case .cHeavySlowResistance:
            return "Do a heavy slow \(lift) at a tempo of 3-1-3. Do this 2 or 3 times each week. This is the main capacity phase. It often continues for months."
        }
    }

    /// Honest QL copy. Phases stay so the diary has a place to stand.
    /// They are not the patellar tendon ladder. Clinical targets are TBD.
    private static func qlSummary(for phase: RehabPhase, modality: String) -> String {
        switch phase {
        case .aFlareDeLoad:
            return "Decrease the load. Record \(modality.lowercased()) if the pain is acceptable. Clinical targets are not set."
        case .bIsometrics, .cHeavySlowResistance:
            return "Continue to record \(modality.lowercased()). The last load is the start value for the next session. Clinical targets are not set."
        }
    }

    static let medicalDisclaimer = BrandCopy.disclaimerBody

    static let redFlags = """
    See a clinician if the resting pain is 5 or more. See a clinician if there is no improvement after 7 to 10 days of less load. See a clinician for swelling, locking, or instability. See a clinician for sharp joint pain. Sharp joint pain is not the usual tendon pain.
    """
}
