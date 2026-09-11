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
    Day to day that looks like Record, Reload, Resolve: morning pain, one lift (default seated leg extension), then Better / Same / Worse. Mild pain during load is OK if the next morning is not worse.
    """

    static let settingsSectionTitle = "Why R3hab"
    static let settingsBlurb = """
    R3hab is rehab with a 3: Identity, Process, Outcome — a habit of informed rehab. Session streaks count Process votes. No badges.
    """
}

/// Short Today lines. Original R3hab copy, paraphrased habit ideas, and
/// single-sentence public-domain / proverb attributions. No book excerpts.
enum MotivationalQuotes {
    static let all: [MotivationalQuote] = [
        MotivationalQuote(text: "Train today. Judge tomorrow.", attribution: "R3hab"),
        MotivationalQuote(
            text: "Each log is a vote for the person who doses by the next morning.",
            attribution: "R3hab"
        ),
        MotivationalQuote(
            text: "Missing once is a dip. Missing twice is a new groove.",
            attribution: "Inspired by Atomic Habits"
        ),
        MotivationalQuote(
            text: "The chain is the process — not a badge.",
            attribution: "R3hab"
        ),
        MotivationalQuote(
            text: "Mild pain during the set is OK if the morning stays calm.",
            attribution: "R3hab"
        ),
        MotivationalQuote(text: "Soft cut before hard drop.", attribution: "R3hab"),
        MotivationalQuote(text: "You own the phase.", attribution: "R3hab"),
        MotivationalQuote(text: "Process first. Outcome follows.", attribution: "R3hab"),
        MotivationalQuote(
            text: "We are what we repeatedly do.",
            attribution: "Will Durant, after Aristotle"
        ),
        MotivationalQuote(
            text: "Little by little, a little becomes a lot.",
            attribution: "Tanzanian proverb"
        ),
        MotivationalQuote(text: "Log the set. The morning tells the truth.", attribution: "R3hab"),
        MotivationalQuote(
            text: "Don’t break the chain — one seated extension still counts.",
            attribution: "R3hab, inspired by Atomic Habits"
        ),
        MotivationalQuote(text: "Capacity is built in quiet sessions.", attribution: "R3hab")
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
