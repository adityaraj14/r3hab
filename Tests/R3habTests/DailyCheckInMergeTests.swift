import XCTest
@testable import R3hab

/// The editor never retains a `DailyCheckIn`. It builds a value draft, merges
/// it over whatever the row holds *at save time*, and the store does
/// fetch-or-insert by dayKey. These pin the merge so a focused editor cannot
/// clobber the other half of the day.
final class DailyCheckInMergeTests: XCTestCase {
    private let existingRow = DailyCheckInValues(
        restingPainAM: 3,
        dailyPainPM: 2,
        steps: 6400,
        phase: .bIsometrics,
        notes: "old note",
        declineSquatL: 1,
        declineSquatR: 2
    )

    func testMorningFocusOnlyWritesMorningFieldsAndPhase() {
        let draft = DailyCheckInValues(restingPainAM: 1, dailyPainPM: nil, steps: nil, phase: .aFlareDeLoad, notes: "new")
        let merged = DailyCheckInMerge.merge(existing: existingRow, draft: draft, focus: .morning)
        XCTAssertEqual(merged.restingPainAM, 1)
        XCTAssertEqual(merged.phase, .aFlareDeLoad)
        XCTAssertEqual(merged.notes, "new")
        // Evening half untouched even though the draft carried nils.
        XCTAssertEqual(merged.dailyPainPM, 2)
        XCTAssertEqual(merged.steps, 6400)
        XCTAssertEqual(merged.declineSquatL, 1)
        XCTAssertEqual(merged.declineSquatR, 2)
    }

    func testEveningFocusOnlyWritesEveningFields() {
        let draft = DailyCheckInValues(restingPainAM: nil, dailyPainPM: 4, steps: 8000, phase: .cHeavySlowResistance, notes: "pm", declineSquatL: nil, declineSquatR: 3)
        let merged = DailyCheckInMerge.merge(existing: existingRow, draft: draft, focus: .evening)
        XCTAssertEqual(merged.dailyPainPM, 4)
        XCTAssertEqual(merged.steps, 8000)
        XCTAssertNil(merged.declineSquatL)
        XCTAssertEqual(merged.declineSquatR, 3)
        XCTAssertEqual(merged.notes, "pm")
        // Morning half and phase untouched.
        XCTAssertEqual(merged.restingPainAM, 3)
        XCTAssertEqual(merged.phase, .bIsometrics)
    }

    func testFullFocusReplacesEverything() {
        let draft = DailyCheckInValues(restingPainAM: 0, dailyPainPM: 0, steps: nil, phase: .cHeavySlowResistance, notes: "")
        let merged = DailyCheckInMerge.merge(existing: existingRow, draft: draft, focus: .full)
        XCTAssertEqual(merged, draft)
    }

    func testMergeWithoutExistingRowIsInsertShapedFromDraft() {
        let morning = DailyCheckInValues(restingPainAM: 2, phase: .bIsometrics, notes: "first")
        let merged = DailyCheckInMerge.merge(existing: nil, draft: morning, focus: .morning)
        XCTAssertEqual(merged.restingPainAM, 2)
        XCTAssertEqual(merged.phase, .bIsometrics)
        XCTAssertNil(merged.dailyPainPM)
        XCTAssertNil(merged.steps)
        XCTAssertEqual(merged.notes, "first")

        let evening = DailyCheckInValues(dailyPainPM: 5, steps: 3000, phase: .aFlareDeLoad)
        let mergedPM = DailyCheckInMerge.merge(existing: nil, draft: evening, focus: .evening)
        XCTAssertNil(mergedPM.restingPainAM)
        XCTAssertEqual(mergedPM.dailyPainPM, 5)
        XCTAssertEqual(mergedPM.steps, 3000)
        XCTAssertEqual(mergedPM.phase, .aFlareDeLoad, "insert takes the draft phase")
    }

    func testSaveMergesOverCurrentRowNotTheRowSeenAtOpen() {
        // Simulates: editor opened with the morning half, app suspended, another
        // path wrote evening pain, then the user hit Save on the morning sheet.
        let seenAtOpen = DailyCheckInValues(restingPainAM: 3, phase: .bIsometrics)
        let currentAtSave = DailyCheckInValues(restingPainAM: 3, dailyPainPM: 6, steps: 5000, phase: .bIsometrics)
        let draft = DailyCheckInValues(restingPainAM: 2, phase: .bIsometrics, notes: seenAtOpen.notes)
        let merged = DailyCheckInMerge.merge(existing: currentAtSave, draft: draft, focus: .morning)
        XCTAssertEqual(merged.restingPainAM, 2)
        XCTAssertEqual(merged.dailyPainPM, 6, "evening written during suspend survives the morning save")
        XCTAssertEqual(merged.steps, 5000)
    }

    func testStepsParsing() {
        XCTAssertEqual(DailyCheckInMerge.steps(from: ""), .empty)
        XCTAssertEqual(DailyCheckInMerge.steps(from: "   "), .empty)
        XCTAssertEqual(DailyCheckInMerge.steps(from: " 6400 "), .value(6400))
        XCTAssertEqual(DailyCheckInMerge.steps(from: "0"), .value(0))
        XCTAssertEqual(DailyCheckInMerge.steps(from: "-1"), .invalid)
        XCTAssertEqual(DailyCheckInMerge.steps(from: "6.4k"), .invalid)
    }

    func testValidationOnlyChecksScoresTheFocusShowed() {
        let badEvening = DailyCheckInValues(restingPainAM: 2, dailyPainPM: 11, phase: .bIsometrics)
        XCTAssertNil(DailyCheckInMerge.validationError(draft: badEvening, focus: .morning))
        XCTAssertNotNil(DailyCheckInMerge.validationError(draft: badEvening, focus: .evening))
        XCTAssertNotNil(DailyCheckInMerge.validationError(draft: badEvening, focus: .full))

        let badMorning = DailyCheckInValues(restingPainAM: -1, dailyPainPM: 2, phase: .bIsometrics)
        XCTAssertNotNil(DailyCheckInMerge.validationError(draft: badMorning, focus: .morning))
        XCTAssertNil(DailyCheckInMerge.validationError(draft: badMorning, focus: .evening))

        let fine = DailyCheckInValues(restingPainAM: 0, dailyPainPM: 10, phase: .bIsometrics, declineSquatL: 4)
        XCTAssertNil(DailyCheckInMerge.validationError(draft: fine, focus: .full))
    }
}
