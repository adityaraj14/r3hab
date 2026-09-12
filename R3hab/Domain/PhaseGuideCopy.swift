import Foundation

enum PhaseGuideCopy {
    static let protocolRevision = "v1.2 · 2026-09-11"

    static func summary(
        for phase: RehabPhase,
        primaryLift: String = PrimaryLoadCatalog.defaultSelectable.title,
        track: RehabTrackID = .knee
    ) -> String {
        let lift = primaryLift.lowercased()
        if track == .ql {
            switch phase {
            case .aFlareDeLoad:
                return "Ease the spasm. Walk if mornings stay calm. Skip loaded side bends and heavy hip thrusts until resting pain settles."
            case .bIsometrics:
                return "Primary work is \(lift). Hip thrusts and standing side bends are the loaded votes; walking does not count toward the 48h chain. Judge by tomorrow morning."
            case .cHeavySlowResistance:
                return "Load \(lift) slowly. Keep walking easy. Don’t jump hip-thrust load and long walks the same week."
            case .dEnergyStorage, .eReturnToSport:
                return "Same three movements. Return to sport or longer walks only if the next morning stays calm."
            }
        }
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

    static let medicalDisclaimer = "R3hab supports self-managed rehab logging. It is not a medical device and does not replace professional care."

    static let redFlags = """
    See a clinician if: resting pain 5+, no improvement after 7–10 days of de-load, swelling, locking, instability, or sharp joint pain (not usual tendon ache).
    """
}
