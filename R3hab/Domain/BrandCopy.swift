import Foundation

struct BrandHabit: Identifiable, Hashable, Sendable {
    var title: String
    var body: String
    var id: String { title }
}

struct MotivationalQuote: Identifiable, Hashable, Sendable {
    var text: String
    var attribution: String?
    var id: String { text }
}

/// Onboarding and Settings product copy. Personal assistant — not a name story.
enum BrandCopy {
    static let onboardingEyebrow = "Welcome"
    static let onboardingTitle = "Your personal rehab assistant."

    static let onboardingLead = """
    Rehab isn’t a straight line. R3hab keeps the journey on this phone, so when doubt shows up you look at your numbers instead of re-telling the whole story.
    """

    static let habits: [BrandHabit] = [
        // Bodies stay under ~45 characters so each is one line at footnote
        // size on a 6.1" phone — the Welcome page is laid out to fit, not scroll.
        BrandHabit(
            title: "Track the journey",
            body: "Pain, sessions, and load in one place."
        ),
        BrandHabit(
            title: "Stay accountable",
            body: "Small, honest logs — enough to keep going."
        ),
        BrandHabit(
            title: "Trust the data",
            body: "Decide from your numbers, not the messy week."
        )
    ]

    static let injuryTitle = "Built for the patellar tendon."

    static let injuryLead = """
    Jumper’s knee and patellar tendinopathy (also called patellar tendonitis) are the same injury and share one knee protocol: progressive loading, judged by the next morning.
    """

    static let injuryDiagnosisNote = """
    Getting a professional diagnosis first is recommended. R3hab helps you track and decide from your own numbers — it isn’t a diagnosis, and we don’t take on the risk if you move ahead without care.
    """

    static let primaryLiftLead = "This is the lift you dose the same way. Switch later in Settings."

    static let setupEyebrow = "Setup"
    static let setupTitle = "Where are you right now?"
    static let setupLead = """
    Rehab here moves in phases — from protecting a flare, to easy loading, to heavier work later. You only pick a starting point. Change it anytime in Settings when mornings tell you to.
    """

    static let setupPhaseLines: [BrandHabit] = [
        BrandHabit(
            title: "Phase A · Flare / protect",
            body: "Ease off. Relative rest until resting pain settles."
        ),
        BrandHabit(
            title: "Phase B · Already loading",
            body: "Easy, consistent isometric work (your primary lift). Most people start here."
        ),
        BrandHabit(
            title: "Later (C →)",
            body: "Heavier slow loading, then return. You’ll grow into these; no need to choose them now."
        )
    ]

    static let disclaimerEyebrow = "Before you start"
    static let disclaimerTitle = "Not a clinic — and that’s intentional."
    static let disclaimerBody = """
    R3hab is a personal log for your rehab journey. It helps you see patterns and decide with data. It is not a medical device, not a diagnosis, and not a substitute for a clinician. If something feels wrong — sharp joint pain, swelling, locking, or pain that won’t settle — see a professional.
    """

    static let settingsSectionTitle = "Why R3hab"
    static let settingsBlurb = """
    R3hab is your personal rehab assistant. Logs stay on this iPhone — private, no ads. When the week feels messy, look at the numbers instead of re-arguing the plan.
    """

    static let privacyEyebrow = "Private"
    static let privacyTitle = "Yours. On this phone."
    static let privacyLead = "A diary, not a product that sells you."
    /// One-line version for the compact Welcome card.
    static let privacySummary = "No account · No ads · Stored on this iPhone only"

    static let privacyPoints: [BrandHabit] = [
        BrandHabit(
            title: "Completely private",
            body: "No account. No cloud login. Pain and sessions never leave this device."
        ),
        BrandHabit(
            title: "No ads",
            body: "Nothing to tap through. Nothing watching the set."
        ),
        BrandHabit(
            title: "On-device only",
            body: "Stored on this iPhone only. Export a file if you want a backup — we don’t host one."
        )
    ]
}

/// Short Today lines. 10-item cycle in R3hab’s own voice — short, neutral,
/// rehab-owned. No franchise memes, no Atomic Habits process copy. The one
/// attributed line is a proverb, not a film.
enum MotivationalQuotes {
    static let all: [MotivationalQuote] = [
        MotivationalQuote(text: "Show up. Log it. Move on.", attribution: nil),
        MotivationalQuote(text: "Calm mornings are the win.", attribution: nil),
        MotivationalQuote(text: "Fall down seven times, stand up eight.", attribution: "Japanese proverb"),
        MotivationalQuote(text: "Consistency beats intensity.", attribution: nil),
        MotivationalQuote(text: "Load a little. Judge it tomorrow morning.", attribution: nil),
        MotivationalQuote(text: "Tendons adapt slowly. So do habits.", attribution: nil),
        MotivationalQuote(text: "Trust the numbers, not the mood.", attribution: nil),
        MotivationalQuote(text: "One session at a time.", attribution: nil),
        MotivationalQuote(text: "A flat week is still a week logged.", attribution: nil),
        MotivationalQuote(text: "Progress hides in ordinary days.", attribution: nil)
    ]

    static func dailyIndex(on date: Date, calendar: Calendar = .current) -> Int {
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        return (day - 1) % all.count
    }

    static func quote(dayIndex: Int, tapOffset: Int) -> MotivationalQuote {
        let count = all.count
        let index = ((dayIndex + tapOffset) % count + count) % count
        return all[index]
    }
}
