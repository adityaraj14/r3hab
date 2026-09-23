import XCTest
@testable import R3hab

final class BrandCopyTests: XCTestCase {
    func testQuoteCycleIsAdisSignedOffListFromPR14PlusAtomicHabits() {
        // Wording and order exactly as merged in PR 14 (build 19); slot 11 is
        // the later-approved Atomic Habits paraphrase.
        XCTAssertEqual(
            MotivationalQuotes.all.map { ($0.text, $0.attribution ?? "") }.map { "\($0.0) — \($0.1)" },
            [
                "Just keep swimming. — Finding Nemo",
                "Get up. — Rocky",
                "Fall down seven times, stand up eight. — Japanese proverb",
                "I can do this all day. — Captain America",
                "Why do we fall? So we can learn to pick ourselves up. — Batman Begins",
                "Do or do not. There is no try. — The Empire Strikes Back",
                "Don't stop believing. — Journey",
                "Believe. — Ted Lasso",
                "Hakuna matata. — The Lion King",
                "The night is darkest just before the dawn. — The Dark Knight",
                "The greatest threat to success is not failure but boredom. Keep going. — Inspired by Atomic Habits"
            ]
        )
        XCTAssertEqual(MotivationalQuotes.all.count, 11)
        XCTAssertEqual(Set(MotivationalQuotes.all.map(\.text)).count, 11)
        XCTAssertTrue(MotivationalQuotes.all.allSatisfy { $0.attribution != nil }, "every line is attributed")
    }

    func testR3habVoiceProcessLinesAreGone() {
        let retired = [
            "Every other day. Keep showing up.",
            "Show up. Log it. Move on.",
            "Load a little. Judge it tomorrow morning.",
            "Tendons adapt slowly"
        ]
        for quote in MotivationalQuotes.all {
            for line in retired {
                XCTAssertFalse(quote.text.localizedCaseInsensitiveContains(line), quote.text)
            }
            XCTAssertNotEqual(quote.attribution, "R3hab")
        }
    }

    func testAdisAtomicHabitsLineIsInSlotEleven() {
        let last = MotivationalQuotes.all[10]
        XCTAssertEqual(last.text, "The greatest threat to success is not failure but boredom. Keep going.")
        XCTAssertEqual(last.attribution, "Inspired by Atomic Habits")
        XCTAssertFalse(last.text.contains("strength"), "Adi asked for the threat/boredom wording")
    }

    func testQuotesStayShortEnoughForTheTodayStreakLine() {
        // Rendered as “text” — attribution at footnote size, lineLimit(2) on Today.
        for quote in MotivationalQuotes.all {
            XCTAssertLessThanOrEqual(quote.text.count, 80, quote.text)
        }
    }

    // MARK: Onboarding pack (Adi, Sep 2026)

    func testWelcomeCopyIsAdis() {
        XCTAssertEqual(BrandCopy.onboardingEyebrow, "Welcome")
        XCTAssertEqual(BrandCopy.onboardingTitle, "Your personal rehab assistant.")
        XCTAssertEqual(
            BrandCopy.onboardingLead,
            "R3hab helps you stay on track with your rehab. When you wonder if you’re going the right way, open the app and look at the data. You don’t have to unpack the whole journey every time doubt shows up — let the numbers guide you."
        )
        XCTAssertEqual(BrandCopy.privacySummary, "No account · No ads · Stored entirely on your iPhone")
    }

    func testWelcomeShowsTheThreeTenets() {
        XCTAssertEqual(BrandCopy.tenets.map(\.title), ["Reduce", "Rebuild", "Return"])
        XCTAssertEqual(
            BrandCopy.tenets.map(\.body),
            [
                "Ease pain and load while the flare settles.",
                "Progressive strength into the tendon (isometrics → HSR).",
                "Back to the activity — or daily life — that got you here."
            ]
        )
        XCTAssertEqual(BrandCopy.tenetLine, "R3 · Reduce · Rebuild · Return")
        XCTAssertFalse(BrandCopy.onboardingTitle.contains("3"))
    }

    func testBenefitCardsMovedFromWelcomeToSettings() {
        XCTAssertEqual(
            BrandCopy.benefits.map(\.title),
            ["Track the journey", "Stay accountable", "Trust the data", "Your data is yours"]
        )
        XCTAssertEqual(
            BrandCopy.benefits.map(\.body),
            [
                "Pain, sessions, and load in one place.",
                "Show up, log it, keep the chain going.",
                "Decisions backed by real data from your hard work.",
                "Export anytime from Settings."
            ]
        )
        let welcomeTitles = Set(BrandCopy.tenets.map(\.title))
        for benefit in BrandCopy.benefits {
            XCTAssertFalse(welcomeTitles.contains(benefit.title), "\(benefit.title) is off Welcome")
        }
        XCTAssertEqual(BrandCopy.settingsSectionTitle, "Why R3hab")
    }

    func testPhasesKeepTheirNamesAndSetupFramesThemAsTenets() {
        XCTAssertEqual(
            BrandCopy.setupTenetFraming,
            "Phase A is Reduce. B and C are Rebuild. Return is the goal — we’ll get there."
        )
        for phase in RehabPhase.allCases {
            for tenet in BrandCopy.tenets {
                XCTAssertFalse(phase.title.contains(tenet.title), phase.title)
            }
        }
    }

    func testInjuryPageConfirmsOneInjuryWithNoComingSoonPromise() {
        XCTAssertEqual(BrandCopy.injuryTitle, "Confirm your injury")
        for rejected in ["Select your injury", "What’s your injury", "Choose your starting injury"] {
            XCTAssertNotEqual(BrandCopy.injuryTitle, rejected)
        }
        XCTAssertEqual(
            InjuryCatalog.patellarTendinopathy.title,
            "Jumper’s knee / patellar tendinopathy / patellar tendonitis"
        )
        XCTAssertTrue(BrandCopy.injuryDiagnosisNote.contains("professional diagnosis"))
        // App Review: no placeholders that imply unfinished features.
        for line in [BrandCopy.injuryTitle, BrandCopy.injuryDiagnosisNote, BrandCopy.settingsBlurb] {
            XCTAssertFalse(line.localizedCaseInsensitiveContains("coming soon"), line)
            XCTAssertFalse(line.localizedCaseInsensitiveContains("more tracks"), line)
        }
    }

    func testPrimaryLiftCopyIsLabelsOnly() {
        XCTAssertEqual(BrandCopy.primaryLiftTitle, "Pick your resistance lift")
        XCTAssertEqual(
            BrandCopy.primaryLiftLead,
            "Choose the exercise you’ll use during the resistance training phase."
        )
        XCTAssertEqual(BrandCopy.primaryLiftTip, "Prefer something convenient and easy to stick with.")
        XCTAssertEqual(PrimaryLoadCatalog.all.map(\.title), ["Seated leg extension", "Leg press"])
    }

    func testSetupPageHasThreeSelectablePhasesWithInlineExplanations() {
        XCTAssertEqual(BrandCopy.setupTitle, "Where are you right now?")
        XCTAssertEqual(BrandCopy.setupLead, "Pick your starting point. Change it anytime in Settings.")
        XCTAssertEqual(
            BrandCopy.setupPhaseChoices.map(\.phase),
            [.aFlareDeLoad, .bIsometrics, .cHeavySlowResistance]
        )
        XCTAssertEqual(
            BrandCopy.setupPhaseChoices.map(\.title),
            ["Phase A · Flare", "Phase B · Isometrics", "Phase C · Heavy slow resistance (HSR)"]
        )
        XCTAssertEqual(
            BrandCopy.setupPhaseChoices.map(\.body),
            [
                "Ease off until resting pain settles.",
                "Easy, consistent isometric work with your primary lift.",
                "The main phase for rebuilding the tendon."
            ]
        )
        XCTAssertEqual(OnboardingCompletion.initialPhase, .aFlareDeLoad)
    }

    func testDisclaimerTitleAndNotificationsCopy() {
        XCTAssertEqual(BrandCopy.disclaimerEyebrow, "Before you start")
        XCTAssertEqual(BrandCopy.disclaimerTitle, "Not a clinic.")
        XCTAssertFalse(BrandCopy.disclaimerTitle.contains("intentional"))
        XCTAssertTrue(BrandCopy.disclaimerBody.contains("not a medical device"))
        XCTAssertEqual(BrandCopy.notificationsToggleTitle, "Notifications")
        XCTAssertEqual(
            BrandCopy.notificationsToggleBody,
            "Reminders for check-ins, workout sessions, and the occasional dose of motivation."
        )
    }

    func testQuoteCycleKeepsBookReferencesToTheOneAdiChose() {
        for quote in MotivationalQuotes.all {
            XCTAssertFalse(quote.text.localizedCaseInsensitiveContains("atomic habits"), quote.text)
            XCTAssertFalse(quote.text.localizedCaseInsensitiveContains("r3hab"), quote.text)
        }
        let bookLines = MotivationalQuotes.all.filter {
            $0.attribution?.localizedCaseInsensitiveContains("atomic habits") == true
        }
        XCTAssertEqual(bookLines.count, 1)
    }

    func testQuoteAdvancesOncePerCalendarDayAndWrapsAcrossElevenSlots() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func day(_ d: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 1, day: d))!
        }

        XCTAssertEqual(MotivationalQuotes.quote(on: day(1), calendar: calendar).text, "Just keep swimming.")
        XCTAssertEqual(MotivationalQuotes.quote(on: day(2), calendar: calendar).text, "Get up.")
        XCTAssertEqual(MotivationalQuotes.quote(on: day(11), calendar: calendar).attribution, "Inspired by Atomic Habits")
        XCTAssertEqual(MotivationalQuotes.quote(on: day(12), calendar: calendar).text, "Just keep swimming.")

        // Same calendar day, any hour → same line. No tap offset exists.
        let morning = calendar.date(byAdding: .hour, value: 7, to: day(5))!
        let night = calendar.date(byAdding: .hour, value: 23, to: day(5))!
        XCTAssertEqual(MotivationalQuotes.quote(on: morning, calendar: calendar), MotivationalQuotes.quote(on: night, calendar: calendar))
        XCTAssertEqual(MotivationalQuotes.quote(on: morning, calendar: calendar).attribution, "Batman Begins")
    }

    func testPrivacyCopyNeverNamesTheStorageFramework() {
        for line in [BrandCopy.privacySummary, BrandCopy.settingsBlurb] {
            XCTAssertFalse(line.contains("SwiftData"), line)
            XCTAssertFalse(line.contains("SQLite"), line)
        }
        XCTAssertTrue(BrandCopy.privacySummary.contains("your iPhone"))
    }

    func testInjuryCopyIsKneeOnlyPlainLanguage() {
        let lines = [
            BrandCopy.injuryTitle,
            InjuryCatalog.patellarTendinopathy.title,
            BrandCopy.injuryDiagnosisNote,
            BrandCopy.primaryLiftLead,
            BrandCopy.primaryLiftTip
        ]
        for line in lines {
            XCTAssertFalse(line.contains("QL"), line)
            XCTAssertFalse(line.localizedCaseInsensitiveContains("hip thrust"), line)
            XCTAssertFalse(line.localizedCaseInsensitiveContains("side bend"), line)
        }
        XCTAssertTrue(InjuryCatalog.patellarTendinopathy.title.contains("patellar tendinopathy"))
    }
}
