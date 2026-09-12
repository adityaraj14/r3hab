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
        // Only the proverb keeps an attribution; every other line is R3hab’s own voice.
        XCTAssertEqual(MotivationalQuotes.all.compactMap(\.attribution), ["Japanese proverb"])
    }

    func testQuotesStayShortEnoughForTheTodayStreakLine() {
        for quote in MotivationalQuotes.all {
            XCTAssertLessThanOrEqual(quote.text.count, 45, quote.text)
        }
    }

    func testWelcomeBenefitBodiesFitOnOneFootnoteLine() {
        // ~313pt of footnote text on a 6.1" phone is ~55 characters; keep headroom.
        for habit in BrandCopy.habits {
            XCTAssertLessThanOrEqual(habit.body.count, 46, habit.body)
            XCTAssertFalse(habit.body.contains("…"), habit.body)
        }
        XCTAssertEqual(
            BrandCopy.habits.map(\.body),
            [
                "Pain, sessions, and load in one place.",
                "Small, honest logs — enough to keep going.",
                "Decide from your numbers, not the messy week."
            ]
        )
    }

    func testQuoteCycleHasNoAtomicHabitsProcessCopy() {
        for quote in MotivationalQuotes.all {
            XCTAssertFalse(quote.text.localizedCaseInsensitiveContains("atomic habits"), quote.text)
            XCTAssertFalse(quote.attribution?.localizedCaseInsensitiveContains("atomic habits") ?? false, quote.text)
            XCTAssertFalse(quote.text.localizedCaseInsensitiveContains("r3hab"), quote.text)
        }
    }

    func testQuoteIndexWrapsAcrossTenSlots() {
        XCTAssertEqual(MotivationalQuotes.quote(dayIndex: 4, tapOffset: 0).text, "Load a little. Judge it tomorrow morning.")
        XCTAssertEqual(MotivationalQuotes.quote(dayIndex: 9, tapOffset: 1).text, MotivationalQuotes.all[0].text)
        XCTAssertEqual(MotivationalQuotes.quote(dayIndex: 0, tapOffset: -1).text, MotivationalQuotes.all[9].text)
    }

    func testPrivacyCopyNeverNamesTheStorageFramework() {
        let all = [BrandCopy.privacyTitle, BrandCopy.privacyLead, BrandCopy.privacySummary, BrandCopy.settingsBlurb]
            + BrandCopy.privacyPoints.flatMap { [$0.title, $0.body] }
        for line in all {
            XCTAssertFalse(line.contains("SwiftData"), line)
            XCTAssertFalse(line.contains("SQLite"), line)
        }
        XCTAssertTrue(BrandCopy.privacyPoints[2].body.contains("this iPhone"))
    }

    func testInjuryTitleIsPlainLanguage() {
        XCTAssertEqual(BrandCopy.injuryTitle, "Which injury are you tracking?")
        XCTAssertFalse(BrandCopy.injuryTitle.localizedCaseInsensitiveContains("loading"))
    }
}
