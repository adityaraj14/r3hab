import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class SessionEditorChromeTests: XCTestCase {
    private func draftFields(
        phase: RehabPhase = .bIsometrics,
        sessionType: SessionType = .isometrics,
        whatIDid: String = "Seated leg extension",
        notes: String = "",
        painDuring: Int? = nil,
        sets: [ResistanceSet] = [ResistanceSet(reps: 8, loadLbs: nil, isWarmup: false)]
    ) -> SessionDraftFields {
        SessionDraftFields(
            phase: phase,
            sessionType: sessionType,
            whatIDid: whatIDid,
            notes: notes,
            painDuring: painDuring,
            sets: sets.map(SessionDraftFields.SetContent.init)
        )
    }

    func testNewLogHidesDeleteAnd24h() {
        let kind = SessionEditorKind.classify(existingIsDraft: nil)
        XCTAssertEqual(kind, .newLog)
        XCTAssertFalse(kind.showsDelete)
        XCTAssertFalse(kind.shows24hResolution)
        XCTAssertFalse(kind.showsAfterPain)
        XCTAssertTrue(kind.showsDraftSave)
    }

    func testDraftHidesDeleteAnd24h() {
        let kind = SessionEditorKind.classify(existingIsDraft: true)
        XCTAssertEqual(kind, .draft)
        XCTAssertFalse(kind.showsDelete)
        XCTAssertFalse(kind.shows24hResolution)
        XCTAssertFalse(kind.showsAfterPain)
        XCTAssertTrue(kind.showsDraftSave)
    }

    func testHistoricalShowsDeleteAnd24hNotAfter() {
        let kind = SessionEditorKind.classify(existingIsDraft: false)
        XCTAssertEqual(kind, .historical)
        XCTAssertTrue(kind.showsDelete)
        XCTAssertTrue(kind.shows24hResolution)
        XCTAssertFalse(kind.showsAfterPain)
        XCTAssertFalse(kind.showsDraftSave)
    }

    func testPickerSelectionHidesPendingAndRest() {
        XCTAssertNil(Session24hResolution.pickerSelection(stored: .pending))
        XCTAssertNil(Session24hResolution.pickerSelection(stored: .notApplicable))
        XCTAssertEqual(Session24hResolution.pickerSelection(stored: .better), .better)
        XCTAssertEqual(Session24hResolution.pickerSelection(stored: .same), .same)
        XCTAssertEqual(Session24hResolution.pickerSelection(stored: .worse), .worse)
    }

    func testWriteLeavesPendingAloneWhenPickerEmpty() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let write = Session24hResolution.write(
            selected: nil,
            storedResponse: .pending,
            storedDecision: nil,
            storedResolvedAt: nil,
            storedSnoozedUntil: now,
            suggestedDecision: .stay,
            now: now
        )
        XCTAssertEqual(
            write,
            Session24hResolution.Write(
                response: .pending,
                decision: nil,
                resolvedAt: nil,
                snoozedUntil: now,
                cancelsPendingNotification: false
            )
        )
    }

    func testWriteLeavesResolvedAloneWhenPickerMatches() {
        let resolved = Date(timeIntervalSince1970: 1_600_000_000)
        let write = Session24hResolution.write(
            selected: .better,
            storedResponse: .better,
            storedDecision: .progress,
            storedResolvedAt: resolved,
            storedSnoozedUntil: nil,
            suggestedDecision: .stay,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(
            write,
            Session24hResolution.Write(
                response: .better,
                decision: .progress,
                resolvedAt: resolved,
                snoozedUntil: nil,
                cancelsPendingNotification: false
            )
        )
    }

    func testWriteOverwritesResponseAndDecision() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snooze = Date(timeIntervalSince1970: 1_650_000_000)
        let write = Session24hResolution.write(
            selected: .worse,
            storedResponse: .pending,
            storedDecision: nil,
            storedResolvedAt: nil,
            storedSnoozedUntil: snooze,
            suggestedDecision: .softCut,
            now: now
        )
        XCTAssertEqual(
            write,
            Session24hResolution.Write(
                response: .worse,
                decision: .softCut,
                resolvedAt: now,
                snoozedUntil: nil,
                cancelsPendingNotification: true
            )
        )
    }

    func testSaveDraftHiddenWhenFormMatchesBaseline() {
        let fields = draftFields()
        XCTAssertFalse(SessionDraftFields.showsSaveDraft(kind: .newLog, current: fields, baseline: fields))
        XCTAssertFalse(SessionDraftFields.showsSaveDraft(kind: .draft, current: fields, baseline: fields))
    }

    func testSaveDraftShownWhenPainNotesOrSetsDiffer() {
        let baseline = draftFields()
        XCTAssertTrue(
            SessionDraftFields.showsSaveDraft(
                kind: .newLog,
                current: draftFields(painDuring: 2),
                baseline: baseline
            )
        )
        XCTAssertTrue(
            SessionDraftFields.showsSaveDraft(
                kind: .draft,
                current: draftFields(notes: "halfway"),
                baseline: baseline
            )
        )
        XCTAssertTrue(
            SessionDraftFields.showsSaveDraft(
                kind: .newLog,
                current: draftFields(sets: [ResistanceSet(reps: 8, loadLbs: 25, isWarmup: false)]),
                baseline: baseline
            )
        )
        let withSet = draftFields(sets: [ResistanceSet(reps: 8, loadLbs: 25, isWarmup: false)])
        XCTAssertTrue(
            SessionDraftFields.showsSaveDraft(
                kind: .draft,
                current: draftFields(sets: [
                    ResistanceSet(reps: 8, loadLbs: 25, isWarmup: false),
                    ResistanceSet(reps: 8, loadLbs: 25, isWarmup: false)
                ]),
                baseline: withSet
            )
        )
    }

    func testSaveDraftIgnoresSetIdentity() {
        let saved = ResistanceSet(reps: 4, loadLbs: 35, holdSeconds: 30, isWarmup: false, side: .left)
        var rebuilt = saved
        rebuilt.id = UUID()
        XCTAssertNotEqual(saved.id, rebuilt.id)
        XCTAssertFalse(
            SessionDraftFields.showsSaveDraft(
                kind: .draft,
                current: draftFields(sets: [rebuilt]),
                baseline: draftFields(sets: [saved])
            )
        )
    }

    func testSaveDraftShownForPhaseTypeAndWalkEdits() {
        let baseline = draftFields()
        XCTAssertTrue(
            SessionDraftFields.showsSaveDraft(
                kind: .newLog,
                current: draftFields(phase: .cHeavySlowResistance),
                baseline: baseline
            )
        )
        XCTAssertTrue(
            SessionDraftFields.showsSaveDraft(
                kind: .draft,
                current: draftFields(sessionType: .hsrStrength, whatIDid: "Leg press"),
                baseline: baseline
            )
        )
        XCTAssertTrue(
            SessionDraftFields.showsSaveDraft(
                kind: .newLog,
                current: draftFields(sets: [ResistanceSet(steps: 4000, durationMinutes: 30)]),
                baseline: draftFields(sets: [ResistanceSet()])
            )
        )
    }

    func testSaveDraftStaysHiddenForHistoricalEdits() {
        let baseline = draftFields()
        XCTAssertFalse(
            SessionDraftFields.showsSaveDraft(
                kind: .historical,
                current: draftFields(notes: "edited", painDuring: 6),
                baseline: baseline
            )
        )
    }

    func testWriteCanOverwriteAResolvedDecision() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let write = Session24hResolution.write(
            selected: .same,
            storedResponse: .better,
            storedDecision: .progress,
            storedResolvedAt: Date(timeIntervalSince1970: 1_600_000_000),
            storedSnoozedUntil: nil,
            suggestedDecision: .stay,
            now: now
        )
        XCTAssertEqual(
            write,
            Session24hResolution.Write(
                response: .same,
                decision: .stay,
                resolvedAt: now,
                snoozedUntil: nil,
                cancelsPendingNotification: true
            )
        )
    }
}
