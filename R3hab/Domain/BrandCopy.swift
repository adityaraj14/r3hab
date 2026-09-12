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
    Rehab isn’t a straight line. Some weeks click; others leave you wondering if you’re on the right path, or if any of it is working. R3hab keeps the journey on this phone — so when doubt shows up, you look at your numbers instead of unpacking the whole story again.
    """

    static let habits: [BrandHabit] = [
        BrandHabit(
            title: "Track the journey",
            body: "Pain, sessions, and load in one place, not just how today felt."
        ),
        BrandHabit(
            title: "Stay accountable",
            body: "Small, honest logs. Enough to keep going without making rehab a second job."
        ),
        BrandHabit(
            title: "Trust the data",
            body: "A quiet system that helps you decide. You don’t have to re-argue the plan every time the week feels messy."
        )
    ]

    static let onboardingFootnote = """
    Log what you did. Check how you feel next. The pattern lives here so you can trust the path you’re on.
    """

    static let injuryLead = """
    Two paths. Jumper’s knee and patellar tendinopathy share the same knee diary. QL strain is its own template: hip thrusts, side bends, and walking.
    """

    static let injuryDiagnosisNote = """
    Getting a professional diagnosis first is recommended. R3hab helps you track and decide from your own numbers — it isn’t a diagnosis, and we don’t take on the risk if you move ahead without care.
    """

    static let primaryLiftLead = "This is the lift you dose the same way. Switch later in Settings."

    static let qlPrimaryWorkLead = "Hip thrusts and side bends carry weight. Walking is time and steps — not fake lbs."

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
            body: "SwiftData on your iPhone. Export a file if you want a backup — we don’t host one."
        )
    ]
}

/// Short Today lines. Adi’s 10 attributed cycle — no R3hab / Atomic Habits process copy.
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
        MotivationalQuote(text: "The night is darkest just before the dawn.", attribution: "The Dark Knight")
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
