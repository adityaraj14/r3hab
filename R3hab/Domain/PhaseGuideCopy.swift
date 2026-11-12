import Foundation

enum PhaseGuideCopy {
    static let protocolRevision = TwelveWeekPlan.protocolRevision

    static func summary(
        for phase: RehabPhase,
        primaryLift: String = PrimaryLoadCatalog.defaultSelectable.title,
        injuryID: String = InjuryCatalog.patellarTendinopathy.id
    ) -> String {
        if InjuryCatalog.isQL(injuryID) {
            return qlSummary(for: phase, modality: primaryLift)
        }
        switch RehabPhase.planPhase(for: phase) {
        case .calmTendon:
            return "Weeks 1–2. Seated leg extension hold, 5 times for 45 seconds, rest 2 minutes. You can do the hold every day. Single-leg leg press, 3×15, slow and light, in a pain-free range. Side-lying hip abduction 3×15 and bodyweight calf raises 3×15. Train Monday, Wednesday, and Friday. Walk or stretch on the other days."
        case .heavySlow:
            return "Weeks 3–6. Seated leg extension and leg press, 4 sets. Reps step from 15 down to 10. 3 seconds up and 3 seconds down. Add weight each week when the next morning stays at baseline. Keep the leg extension hold as the warm-up."
        case .heavier:
            return "Weeks 7–10. Seated leg extension and leg press, 4 sets. Reps step from 8 down to 6. Still slow and heavy. Spanish squat: 5 holds of 45 seconds. Optional. Skip if it bothers your back."
        case .springiness:
            return "Weeks 11–12. Two heavy days. On the third training day add pogo hops 3×20, then box jump-ups 3×8, then landings. Add the next drill only when the next morning does not flare."
        case .aFlareDeLoad, .bIsometrics, .cHeavySlowResistance:
            return summary(for: RehabPhase.planPhase(for: phase), primaryLift: primaryLift, injuryID: injuryID)
        }
    }

    /// Honest QL copy. Phases stay so the diary has a place to stand.
    /// They are not the patellar tendon ladder. Clinical targets are TBD.
    private static func qlSummary(for phase: RehabPhase, modality: String) -> String {
        switch RehabPhase.planPhase(for: phase) {
        case .calmTendon, .aFlareDeLoad, .bIsometrics:
            return "Decrease the load. Record \(modality.lowercased()) if the pain is acceptable. Clinical targets are not set."
        case .heavySlow, .heavier, .springiness, .cHeavySlowResistance:
            return "Continue to record \(modality.lowercased()). The last load is the start value for the next session. Clinical targets are not set."
        }
    }

    static let medicalDisclaimer = BrandCopy.disclaimerBody

    static let redFlags = """
    See a clinician if the resting pain is 5 or more. See a clinician if there is no improvement after 7 to 10 days of less load. See a clinician for swelling, locking, or instability. See a clinician for sharp joint pain. Sharp joint pain is not the usual tendon pain.
    """
}
