import XCTest
@testable import R3hab

final class PainScoreTests: XCTestCase {
    func testSentinelIsNotALoggedScore() {
        XCTAssertEqual(PainScore.notLogged, -1)
        XCTAssertFalse(PainScore.isLogged(-1))
        XCTAssertFalse(PainScore.isLogged(11))
        XCTAssertTrue(PainScore.isLogged(0))
        XCTAssertTrue(PainScore.isLogged(10))
        XCTAssertNil(PainScore.optional(-1))
        XCTAssertEqual(PainScore.optional(4), 4)
        XCTAssertEqual(PainScore.display(-1), "—")
        XCTAssertEqual(PainScore.display(3), "3")
        XCTAssertNil(PainScore.chartValue(-1))
        XCTAssertEqual(PainScore.chartValue(2), 2)
    }

    func testSaveAllowsMissingAfterAndRequiresDuring() {
        XCTAssertEqual(
            SessionSaveValidation.validate(
                painDuring: nil,
                painAfter: nil,
                whatIDid: "Seated extension",
                sets: []
            ),
            .missingPainDuring
        )
        XCTAssertNil(
            SessionSaveValidation.validate(
                painDuring: 3,
                painAfter: nil,
                whatIDid: "Seated extension",
                sets: []
            )
        )
        XCTAssertEqual(
            SessionSaveValidation.validate(
                painDuring: 3,
                painAfter: -1,
                whatIDid: "Seated extension",
                sets: []
            ),
            .painAfterOutOfRange
        )
        XCTAssertEqual(
            SessionSaveValidation.validate(
                painDuring: 3,
                painAfter: nil,
                whatIDid: "  ",
                sets: []
            ),
            .emptyWhatIDid
        )
    }

    func testSaveRejectsBadLoadRows() {
        XCTAssertEqual(
            SessionSaveValidation.validate(
                painDuring: 2,
                painAfter: nil,
                whatIDid: "HSR",
                sets: [ResistanceSet(reps: 0, loadLbs: 15)]
            ),
            .nonPositiveReps
        )
        XCTAssertEqual(
            SessionSaveValidation.validate(
                painDuring: 2,
                painAfter: nil,
                whatIDid: "HSR",
                sets: [ResistanceSet(reps: 8, loadLbs: -1)]
            ),
            .negativeLoad
        )
    }
}
