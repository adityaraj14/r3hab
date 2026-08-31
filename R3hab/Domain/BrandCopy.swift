import Foundation

/// One of the three habits the “3” in R3hab stands for.
struct BrandHabit: Identifiable, Hashable, Sendable {
    var title: String
    var body: String
    var id: String { title }
}

/// Product name story for onboarding and Settings.
///
/// E3 Rehab (the popular PT YouTube channel) uses “E3” for three E’s:
/// Empowerment through Evidence-based Education.
/// R3hab is rehab with the E written as 3 — the same visual trick — and the
/// 3 names this diary’s three habits: Record, Reload, Resolve.
enum BrandCopy {
    static let onboardingEyebrow = "The name"
    static let onboardingTitle = "Rehab, written with a 3."

    static let onboardingLead = """
    The 3 is the E in rehab. It also names the three habits this diary actually tracks.
    """

    static let habits: [BrandHabit] = [
        BrandHabit(
            title: "Record",
            body: "Morning pain, not memory. A number you can compare tomorrow."
        ),
        BrandHabit(
            title: "Reload",
            body: "One primary lift, dosed the same way. Default is seated leg extension — you pick on the next screens."
        ),
        BrandHabit(
            title: "Resolve",
            body: "Train today. Judge tomorrow. Better / Same / Worse drives Stay / Soft cut / Progress."
        )
    ]

    static let onboardingFootnote = """
    Mild pain during load is OK if the next morning is not worse. The 3 shows up again in the protocol: 3 stable mornings to leave Phase A, 3 clean 24h responses before you Progress, 3-1-3 tempo on heavy slow.
    """

    static let settingsSectionTitle = "Why R3hab"
    static let settingsBlurb = """
    R3hab is rehab with a 3: Record pain, Reload one lift, Resolve 24 hours later.
    """
}
