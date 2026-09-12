import XCTest
@testable import R3hab

final class BrandCopyTests: XCTestCase {
    func testQuoteCycleStaysTenAndDropsTheBatmanBeginsLine() {
        XCTAssertEqual(MotivationalQuotes.all.count, 10)
        XCTAssertFalse(MotivationalQuotes.all.contains { $0.attribution == "Batman Begins" })
        XCTAssertFalse(MotivationalQuotes.all.contains { $0.text.contains("Why do we fall") })
        XCTAssertTrue(MotivationalQuotes.all.contains { $0.text == "Load a little. Judge it tomorrow morning." })
        XCTAssertEqual(Set(MotivationalQuotes.all.map(\.text)).count, 10)
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
