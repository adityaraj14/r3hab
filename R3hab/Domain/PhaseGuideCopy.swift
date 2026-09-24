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
            return "Relative rest. No heavy knee loading, impact, or tennis. Optional easy bike if pain-free. Aim for 3 stable mornings ≤2 with a ~6k+ step day before Phase B."
        case .bIsometrics:
            return "Primary load is \(lift) holds. Start 3–4×20–30s, 2×/week, ≥48h apart. Build holds before adding days."
        case .cHeavySlowResistance:
            return "Heavy slow \(lift), slow tempo (3-1-3), 2–3×/week. Main capacity phase — often months."
        }
    }

    /// Honest QL copy. Phases stay so the diary has a place to stand.
    /// They are not the patellar tendon ladder. Clinical targets are TBD.
    private static func qlSummary(for phase: RehabPhase, modality: String) -> String {
        switch phase {
        case .aFlareDeLoad:
            return "Ease off. Log \(modality.lowercased()) if it feels okay. Clinical targets are TBD."
        case .bIsometrics, .cHeavySlowResistance:
            return "Keep logging \(modality.lowercased()). Last load prefills the next weighted session. Clinical targets are TBD."
        }
    }

    static let medicalDisclaimer = BrandCopy.disclaimerBody

    static let redFlags = """
    See a clinician if: resting pain 5+, no improvement after 7–10 days of de-load, swelling, locking, instability, or sharp joint pain (not usual tendon ache).
    """
}
