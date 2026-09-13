import Foundation

struct BrandHabit: Identifiable, Hashable, Sendable {
    var title: String
    var body: String
    var id: String { title }
}

struct SetupPhaseChoice: Identifiable, Hashable, Sendable {
    var phase: RehabPhase
    var title: String
    var body: String
    var id: RehabPhase { phase }
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
    R3hab helps you stay on track with your rehab. When you wonder if you’re going the right way, open the app and look at the data. You don’t have to unpack the whole journey every time doubt shows up — let the numbers guide you.
    """

    static let habits: [BrandHabit] = [
        // Bodies stay one line at footnote size on a 6.1" phone (~55 characters)
        // — the Welcome page is laid out to fit, not scroll.
        BrandHabit(
            title: "Track the journey",
            body: "Pain, sessions, and load in one place."
        ),
        BrandHabit(
            title: "Stay accountable",
            body: "Show up, log it, keep the chain going."
        ),
        BrandHabit(
            title: "Trust the data",
            body: "Decisions backed by real data from your hard work."
        ),
        BrandHabit(
            title: "Your data is yours",
            body: "Export anytime from Settings."
        )
    ]

    /// One injury ships today, so this page confirms and teases more — it is
    /// not a picker.
    static let injuryTitle = "Confirm your injury"
    static let injuryComingSoonTitle = "More injuries coming soon"
    static let injuryComingSoonBody = "We’ll add more tracks over time."

    static let injuryDiagnosisNote = """
    Getting a professional diagnosis first is recommended. R3hab helps you track and decide from your own numbers — it isn’t a diagnosis, and we don’t take on the risk if you move ahead without care.
    """

    static let primaryLiftTitle = "Pick your resistance lift"
    static let primaryLiftLead = "Choose the exercise you’ll use during the resistance training phase."
    static let primaryLiftTip = "Prefer something convenient and easy to stick with."

    static let setupEyebrow = "Setup"
    static let setupTitle = "Where are you right now?"
    static let setupLead = "Pick your starting point. Change it anytime in Settings."

    /// The three selectable starting points. Title + explanation live on the
    /// card itself; there is no separate phase explainer.
    static let setupPhaseChoices: [SetupPhaseChoice] = [
        SetupPhaseChoice(
            phase: .aFlareDeLoad,
            title: "Phase A · Flare",
            body: "Ease off until resting pain settles."
        ),
        SetupPhaseChoice(
            phase: .bIsometrics,
            title: "Phase B · Isometrics",
            body: "Easy, consistent isometric work with your primary lift."
        ),
        SetupPhaseChoice(
            phase: .cHeavySlowResistance,
            title: "Phase C · Heavy slow resistance (HSR)",
            body: "The main phase for rebuilding the tendon."
        )
    ]

    static let disclaimerEyebrow = "Before you start"
    static let disclaimerTitle = "Not a clinic."
    static let disclaimerBody = """
    R3hab is a personal log for your rehab journey. It helps you see patterns and decide with data. It is not a medical device, not a diagnosis, and not a substitute for a clinician. If something feels wrong — sharp joint pain, swelling, locking, or pain that won’t settle — see a professional.
    """

    static let notificationsToggleTitle = "Notifications"
    static let notificationsToggleBody =
        "Reminders for check-ins, workout sessions, and the occasional dose of motivation."

    static let settingsSectionTitle = "Why R3hab"
    static let settingsBlurb = """
    R3hab is your personal rehab assistant. Logs stay on this iPhone — private, no ads. When the week feels messy, look at the numbers instead of re-arguing the plan.
    """

    /// The one-line privacy card on Welcome.
    static let privacySummary = "No account · No ads · Stored entirely on your iPhone"
}

/// Adi’s signed-off cycle: the 10 attributed lines from PR 14, wording
/// unchanged, plus his later Atomic Habits paraphrase as slot 11. One line
/// per calendar day, no tap-to-cycle. No R3hab-voice process copy.
enum MotivationalQuotes {
    static let all: [MotivationalQuote] = [
        MotivationalQuote(text: "Just keep swimming.", attribution: "Finding Nemo"),
        MotivationalQuote(text: "Get up.", attribution: "Rocky"),
        MotivationalQuote(text: "Fall down seven times, stand up eight.", attribution: "Japanese proverb"),
        MotivationalQuote(text: "I can do this all day.", attribution: "Captain America"),
        MotivationalQuote(text: "Why do we fall? So we can learn to pick ourselves up.", attribution: "Batman Begins"),
        MotivationalQuote(text: "Do or do not. There is no try.", attribution: "The Empire Strikes Back"),
        MotivationalQuote(text: "Don't stop believing.", attribution: "Journey"),
        MotivationalQuote(text: "Believe.", attribution: "Ted Lasso"),
        MotivationalQuote(text: "Hakuna matata.", attribution: "The Lion King"),
        MotivationalQuote(text: "The night is darkest just before the dawn.", attribution: "The Dark Knight"),
        MotivationalQuote(
            text: "The greatest threat to success is not failure but boredom. Keep going.",
            attribution: "Inspired by Atomic Habits"
        )
    ]

    /// Day-of-year walk through the list. Advances once per calendar day.
    static func dailyIndex(on date: Date, calendar: Calendar = .current) -> Int {
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        return (day - 1) % all.count
    }

    static func quote(on date: Date, calendar: Calendar = .current) -> MotivationalQuote {
        all[dailyIndex(on: date, calendar: calendar)]
    }
}
