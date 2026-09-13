import Foundation

enum PhaseGuideCopy {
    static let protocolRevision = "v1.2 · 2026-09-11"

    static func summary(
        for phase: RehabPhase,
        primaryLift: String = PrimaryLoadCatalog.defaultSelectable.title
    ) -> String {
        let lift = primaryLift.lowercased()
        switch phase {
        case .aFlareDeLoad:
            return "Relative rest. No heavy knee loading, impact, or tennis. Optional easy bike if pain-free. Aim for 3 stable mornings ≤2 with a ~6k+ step day before Phase B."
        case .bIsometrics:
            return "Primary load is \(lift) holds. Start 3–4×20–30s, 2×/week, ≥48h apart. Build holds before adding days."
        case .cHeavySlowResistance:
            return "Heavy slow \(lift), slow tempo (3-1-3), 2–3×/week. Main capacity phase — often months."
        case .dEnergyStorage:
            return "Add low-volume landings and light plyos while keeping some \(lift) strength work. Quality over volume."
        case .eReturnToSport:
            return "Gradual tennis return. Keep 1–2 \(lift) days/week. Don’t jump gym load and tennis volume the same week."
        }
    }

    static let medicalDisclaimer = BrandCopy.disclaimerBody

    static let redFlags = """
    See a clinician if: resting pain 5+, no improvement after 7–10 days of de-load, swelling, locking, instability, or sharp joint pain (not usual tendon ache).
    """
}
