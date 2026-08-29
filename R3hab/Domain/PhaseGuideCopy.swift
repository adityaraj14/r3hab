import Foundation

enum PhaseGuideCopy {
    static let protocolRevision = "v1.1 · 2026-08-10"

    static func summary(for phase: RehabPhase) -> String {
        switch phase {
        case .aFlareDeLoad:
            return "Relative rest. No heavy knee loading, impact, or tennis. Optional easy bike if pain-free. Aim for 3 stable mornings ≤2 with a ~6k+ step day before Phase B."
        case .bIsometrics:
            return "Primary load is seated knee extension holds. Start 3–4×20–30s, 2×/week, ≥48h apart. Wall sit or Spanish squat only as backups. Build holds before adding days."
        case .cHeavySlowResistance:
            return "Heavy slow seated knee extension, slow tempo (3-1-3), 2–3×/week. Optional leg press. Main capacity phase — often months."
        case .dEnergyStorage:
            return "Add low-volume landings and light plyos while keeping some strength work. Quality over volume."
        case .eReturnToSport:
            return "Gradual tennis return. Keep 1–2 strength days/week. Don’t jump gym load and tennis volume the same week."
        }
    }

    static let medicalDisclaimer = "R3hab supports self-managed rehab logging. It is not a medical device and does not replace professional care."

    static let redFlags = """
    See a clinician if: resting pain 5+, no improvement after 7–10 days of de-load, swelling, locking, instability, or sharp joint pain (not usual tendon ache).
    """
}
