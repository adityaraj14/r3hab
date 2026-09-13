import XCTest
@testable import R3hab

final class BrandCopyTests: XCTestCase {
    func testQuoteCycleStaysTenAndHasNoFranchiseLines() {
        XCTAssertEqual(MotivationalQuotes.all.count, 10)
        XCTAssertEqual(Set(MotivationalQuotes.all.map(\.text)).count, 10)
        XCTAssertTrue(MotivationalQuotes.all.contains { $0.text == "Load a little. Judge it tomorrow morning." })

        let franchise = [
            "Batman Begins", "The Dark Knight", "The Empire Strikes Back", "Finding Nemo",
            "Rocky", "Captain America", "Journey", "Ted Lasso", "The Lion King"
        ]
        let flaggedLines = ["Why do we fall", "Do or do not", "There is no try", "Hakuna", "keep swimming"]
        for quote in MotivationalQuotes.all {
            if let attribution = quote.attribution {
                XCTAssertFalse(franchise.contains(attribution), attribution)
            }
            for flagged in flaggedLines {
                XCTAssertFalse(quote.text.contains(flagged), quote.text)
            }
        }
        // Two attributed lines: the proverb and Adi’s Atomic Habits paraphrase.
        XCTAssertEqual(
            MotivationalQuotes.all.compactMap(\.attribution),
            ["Japanese proverb", "Inspired by Atomic Habits"]
        )
    }

    func testTendonsAdaptSlowlyLineIsRetired() {
        for quote in MotivationalQuotes.all {
            XCTAssertFalse(quote.text.localizedCaseInsensitiveContains("Tendons adapt slowly"), quote.text)
            XCTAssertFalse(quote.text.localizedCaseInsensitiveContains("So do habits"), quote.text)
        }
        XCTAssertEqual(MotivationalQuotes.all[5].text, "Every other day. Keep showing up.")
        XCTAssertNil(MotivationalQuotes.all[5].attribution)
    }

    func testAdisAtomicHabitsLineIsInSlotTen() {
        let last = MotivationalQuotes.all[9]
        XCTAssertEqual(last.text, "The greatest threat to success is not failure but boredom. Keep going.")
        XCTAssertEqual(last.attribution, "Inspired by Atomic Habits")
        XCTAssertFalse(last.text.contains("strength"), "Adi asked for the threat/boredom wording")
    }

    func testQuotesStayShortEnoughForTheTodayStreakLine() {
        // Rendered as “text” — attribution at footnote size, lineLimit(3) on Today.
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

    func testWelcomeBenefitCardsAreTheFourAdiChose() {
        XCTAssertEqual(
            BrandCopy.habits.map(\.title),
            ["Track the journey", "Stay accountable", "Trust the data", "Your data is yours"]
        )
        XCTAssertEqual(
            BrandCopy.habits.map(\.body),
            [
                "Pain, sessions, and load in one place.",
                "Show up, log it, keep the chain going.",
                "Decisions backed by real data from your hard work.",
                "Export anytime from Settings."
            ]
        )
        for habit in BrandCopy.habits {
            XCTAssertFalse(habit.body.contains("Small, honest logs"), habit.body)
            XCTAssertFalse(habit.body.contains("Decide from your numbers"), habit.body)
        }
    }

    func testWelcomeBenefitBodiesFitOnOneFootnoteLine() {
        // ~313pt of footnote text on a 6.1" phone is ~55 characters.
        for habit in BrandCopy.habits {
            XCTAssertLessThanOrEqual(habit.body.count, 55, habit.body)
            XCTAssertFalse(habit.body.contains("…"), habit.body)
        }
    }

    func testInjuryPageConfirmsOneInjuryAndTeasesMore() {
        XCTAssertEqual(BrandCopy.injuryTitle, "Confirm your injury")
        for rejected in ["Select your injury", "What’s your injury", "Choose your starting injury"] {
            XCTAssertNotEqual(BrandCopy.injuryTitle, rejected)
        }
        XCTAssertEqual(
            InjuryCatalog.patellarTendinopathy.title,
            "Jumper’s knee / patellar tendinopathy / patellar tendonitis"
        )
        XCTAssertEqual(BrandCopy.injuryComingSoonTitle, "More injuries coming soon")
        XCTAssertEqual(BrandCopy.injuryComingSoonBody, "We’ll add more tracks over time.")
        XCTAssertTrue(BrandCopy.injuryDiagnosisNote.contains("professional diagnosis"))
    }

    func testPrimaryLiftCopyIsLabelsOnly() {
        XCTAssertEqual(BrandCopy.primaryLiftTitle, "Pick your resistance lift")
        XCTAssertEqual(
            BrandCopy.primaryLiftLead,
            "Choose the exercise you’ll use during the resistance training phase."
        )
        XCTAssertEqual(BrandCopy.primaryLiftTip, "Prefer something convenient and easy to stick with.")
        XCTAssertEqual(PrimaryLoadCatalog.all.map(\.title), ["Seated extension", "Leg press"])
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

    func testQuoteIndexWrapsAcrossTenSlots() {
        XCTAssertEqual(MotivationalQuotes.quote(dayIndex: 4, tapOffset: 0).text, "Load a little. Judge it tomorrow morning.")
        XCTAssertEqual(MotivationalQuotes.quote(dayIndex: 9, tapOffset: 1).text, MotivationalQuotes.all[0].text)
        XCTAssertEqual(MotivationalQuotes.quote(dayIndex: 0, tapOffset: -1).text, MotivationalQuotes.all[9].text)
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
            BrandCopy.injuryComingSoonTitle,
            BrandCopy.injuryComingSoonBody,
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
