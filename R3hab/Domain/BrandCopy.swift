import Foundation

/// Icon + title + one-line body. Tenets on Welcome, benefits in Settings.
struct BrandCard: Identifiable, Hashable, Sendable {
    var icon: String
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
    R3hab helps you with your rehab. When you are not sure, open R3hab. Read the data. Use the numbers for each decision.
    """

    /// The 3 in R3. Welcome shows these three cards and nothing else.
    static let tenetLine = "R3 · Reduce · Rebuild · Return"
    static let tenets: [BrandCard] = [
        BrandCard(
            icon: "arrow.down.circle",
            title: "Reduce",
            body: "Decrease the pain and the load during a flare."
        ),
        BrandCard(
            icon: "figure.strengthtraining.traditional",
            title: "Rebuild",
            body: "Increase tendon strength with isometrics, then with heavy slow resistance (HSR)."
        ),
        BrandCard(
            icon: "figure.run",
            title: "Return",
            body: "Return to your activity or to daily life."
        )
    ]

    /// One injury ships today, so this page confirms — it is not a picker.
    static let injuryTitle = "Your injury"

    static let injuryDiagnosisNote = """
    Get a professional diagnosis first. R3hab helps you record data and decide from your numbers. R3hab is not a diagnosis. R3hab does not accept the risk if you continue without a clinician.
    """

    static let primaryLiftTitle = "Select your exercise"
    static let primaryLiftLead = "Select the exercise for the resistance phase."
    static let primaryLiftTip = "Select an exercise that is easy to continue."

    static let setupEyebrow = "Setup"
    static let setupTitle = "Select your current phase."
    static let setupLead = "Select the start phase. You can change it in Settings."
    /// Ties the phase cards to the tenets without renaming the phases.
    static let setupTenetFraming = "Phase A is Reduce. Phase B and Phase C are Rebuild. Return is the goal."

    /// The three selectable starting points. Title + explanation live on the
    /// card itself; there is no separate phase explainer.
    static let setupPhaseChoices: [SetupPhaseChoice] = [
        SetupPhaseChoice(
            phase: .aFlareDeLoad,
            title: "Phase A · Flare",
            body: "Decrease the load until the resting pain is stable."
        ),
        SetupPhaseChoice(
            phase: .bIsometrics,
            title: "Phase B · Isometrics",
            body: "Do easy isometric holds with your primary exercise."
        ),
        SetupPhaseChoice(
            phase: .cHeavySlowResistance,
            title: "Phase C · Heavy slow resistance (HSR)",
            body: "This phase rebuilds the tendon."
        )
    ]

    static let disclaimerEyebrow = "Before you start"
    static let disclaimerTitle = "R3hab is not a clinic."
    static let disclaimerBody = """
    R3hab is a personal record of your rehab. R3hab helps you see patterns in the data. R3hab helps you decide with the data. R3hab is not a medical device. R3hab is not a diagnosis. R3hab does not replace a clinician. See a clinician for sharp joint pain, swelling, or locking. See a clinician if the pain does not decrease.
    """

    static let notificationsToggleTitle = "Reminders"
    static let notificationsToggleBody =
        "Reminders for check-ins, sessions, and a daily quote."

    static let settingsSectionTitle = "Why R3hab"
    static let settingsBlurb = """
    R3hab is your personal rehab assistant. R3hab stores the records on this iPhone. R3hab has no ads. When a week is difficult, read the numbers.
    """
    static let benefits: [BrandCard] = [
        BrandCard(
            icon: "chart.line.uptrend.xyaxis",
            title: "Record the rehab",
            body: "R3hab keeps pain, sessions, and load together."
        ),
        BrandCard(
            icon: "checkmark.circle",
            title: "Continue the sessions",
            body: "Record each session."
        ),
        BrandCard(
            icon: "scalemass",
            title: "Use the data",
            body: "Use your data for each decision."
        ),
        BrandCard(
            icon: "square.and.arrow.up",
            title: "You control the data",
            body: "You can export the data from Settings."
        )
    ]

    /// The one-line privacy card on Welcome.
    static let privacySummary = "No account. No ads. R3hab stores the data only on your iPhone."
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
