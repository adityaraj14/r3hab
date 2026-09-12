import Foundation

/// One of the three layers the “3” in R3hab stands for.
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

/// Product name story for onboarding and Settings.
///
/// Atomic Habits’ only official triad is the three layers of change:
/// Identity (what you believe), Process (what you do), Outcome (what you get).
/// Lasting habits run inside-out: decide who you are, prove it with a system,
/// and let results follow. R3hab is rehab with the E written as 3, and the 3
/// names those layers — the habit of informed rehab.
///
/// Record / Reload / Resolve is the daily loop that casts the votes:
/// record pain, reload one lift, resolve 24 hours later.
///
/// The book’s four laws are Obvious / Attractive / Easy / Satisfying.
/// This app does three of them (checklist + reminders, 60-second paths,
/// close the 24h loop). Attractive stays light: **session streaks** count
/// Process votes (hard rehab within 48h). Still no gamified badges.
enum BrandCopy {
    static let onboardingEyebrow = "The name"
    static let onboardingTitle = "Rehab, written with a 3."

    static let onboardingLead = """
    The 3 is the E in rehab. It also names the three layers a habit actually sticks at: who you believe you are, what you do, and what you get.
    """

    static let habits: [BrandHabit] = [
        BrandHabit(
            title: "Identity",
            body: "You are someone who judges load by the next morning, not the set. Each log is a vote for informed rehab — you own the phase."
        ),
        BrandHabit(
            title: "Process",
            body: "One primary lift, dosed the same way. Train today. Judge tomorrow. Soft cut before hard drop. The system is the rehab."
        ),
        BrandHabit(
            title: "Outcome",
            body: "Pain, steps, and load you can see. Capacity without guessing. Results come last — after the votes add up."
        )
    ]

    static let onboardingFootnote = """
    Day to day that looks like Record, Reload, Resolve: morning pain, one primary movement, then Better / Same / Worse. Mild pain during load is OK if the next morning is not worse.
    """

    static let injuryLead = """
    Knee labels share the patellar tendon diary. QL strain is its own template: hip thrusts, standing side bends, and walking.
    """

    static let primaryLiftLead = "This is the lift you dose the same way. Switch later in Settings."

    static let qlPrimaryWorkLead = "Hip thrusts and side bends carry weight. Walking is time and steps — not fake lbs."

    static let settingsSectionTitle = "Why R3hab"
    static let settingsBlurb = """
    R3hab is rehab with a 3: Identity, Process, Outcome — a habit of informed rehab. Session streaks count Process votes. No badges. Completely private. No ads. Logs stay on this iPhone.
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
