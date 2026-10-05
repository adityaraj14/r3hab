import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class SessionUpsertTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private var day: Date {
        calendar.startOfDay(for: Date(timeIntervalSince1970: 1_759_449_600)) // 2025-10-03 UTC-ish
    }

    private func snap(
        id: UUID = UUID(),
        date: Date? = nil,
        createdAt: Date? = nil,
        type: SessionType = .hsrStrength,
        whatIDid: String = "Seated leg extension",
        painDuring: Int = 2,
        painAfter: Int = PainScore.notLogged,
        response: Response24h = .pending,
        isDraft: Bool = false,
        sets: [ResistanceSet] = [ResistanceSet(reps: 8, loadLbs: 40, holdSeconds: nil, isWarmup: false)]
    ) -> TrainingSessionSnapshot {
        let d = date ?? day
        return TrainingSessionSnapshot(
            id: id,
            date: calendar.startOfDay(for: d),
            createdAt: createdAt ?? d,
            sessionType: type,
            response24h: response,
            decision: nil,
            resolvedAt: nil,
            snoozedUntil: nil,
            phase: .cHeavySlowResistance,
            painDuring: painDuring,
            painAfter: painAfter,
            isDraft: isDraft,
            whatIDid: whatIDid,
            resistanceSets: sets
        )
    }

    func testDoubleSaveOfSameDraftUpdatesNotInserts() {
        let draftId = UUID()
        let draft = snap(id: draftId, painDuring: PainScore.notLogged, isDraft: true, sets: [])
        // First save would finalize; second Save still holds the same id, now finalized.
        let finalized = snap(id: draftId, createdAt: day.addingTimeInterval(10), isDraft: false)
        let second = SessionUpsert.target(
            preferredId: draftId,
            sessions: [finalized],
            day: day,
            preferring: .hsrStrength,
            calendar: calendar
        )
        XCTAssertEqual(second, SessionUpsert.Target.update(draftId))
    }

    func testSaveWithoutIdReusesOpenDraftForTheDay() {
        let draftId = UUID()
        let draft = snap(id: draftId, type: .hsrStrength, painDuring: PainScore.notLogged, isDraft: true, sets: [])
        let target = SessionUpsert.target(
            preferredId: nil,
            sessions: [draft],
            day: day,
            preferring: .hsrStrength,
            calendar: calendar
        )
        XCTAssertEqual(target, SessionUpsert.Target.update(draftId))
    }

    func testOldEditorDraftIsReusedByGuidedSave() {
        // TF42 draft was isometrics with no guidedStepIndex; TF43 guided save must not insert.
        let draftId = UUID()
        let oldDraft = snap(id: draftId, type: .isometrics, painDuring: PainScore.notLogged, isDraft: true, sets: [])
        let target = SessionUpsert.target(
            preferredId: nil,
            sessions: [oldDraft],
            day: day,
            preferring: .hsrStrength,
            calendar: calendar
        )
        XCTAssertEqual(target, SessionUpsert.Target.update(draftId))
    }

    func testInsertWhenNoDraftExists() {
        let complete = snap(isDraft: false)
        XCTAssertEqual(
            SessionUpsert.target(
                preferredId: nil,
                sessions: [complete],
                day: day,
                preferring: .hsrStrength,
                calendar: calendar
            ),
            SessionUpsert.Target.insert
        )
    }

    func testExactDuplicatePairOnSameDay() {
        let a = snap(id: UUID(), createdAt: day)
        let b = snap(id: UUID(), createdAt: day.addingTimeInterval(30))
        let pairs = SessionDuplicate.pairs(in: [a, b], calendar: calendar)
        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs[0].keepID, a.id)
        XCTAssertEqual(pairs[0].removeID, b.id)
    }

    func testDistinctLoadIsNotADuplicate() {
        let a = snap(sets: [ResistanceSet(reps: 8, loadLbs: 40, holdSeconds: nil, isWarmup: false)])
        let b = snap(sets: [ResistanceSet(reps: 8, loadLbs: 45, holdSeconds: nil, isWarmup: false)])
        XCTAssertTrue(SessionDuplicate.pairs(in: [a, b], calendar: calendar).isEmpty)
    }

    func testDistinctPainIsNotADuplicate() {
        let a = snap(painDuring: 2)
        let b = snap(painDuring: 3)
        XCTAssertTrue(SessionDuplicate.pairs(in: [a, b], calendar: calendar).isEmpty)
    }

    func testKeepsResolvedOverPendingDuplicate() {
        let pending = snap(id: UUID(), createdAt: day, response: .pending)
        let resolved = snap(id: UUID(), createdAt: day.addingTimeInterval(60), response: .better)
        let pairs = SessionDuplicate.pairs(in: [pending, resolved], calendar: calendar)
        XCTAssertEqual(pairs.first?.keepID, resolved.id)
        XCTAssertEqual(pairs.first?.removeID, pending.id)
    }

    func testDraftsAreNeverExactDuplicates() {
        let a = snap(painDuring: PainScore.notLogged, isDraft: true)
        let b = snap(isDraft: false)
        XCTAssertTrue(SessionDuplicate.pairs(in: [a, b], calendar: calendar).isEmpty)
    }

    func testDifferentDaysAreNotMerged() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day)!
        let a = snap(date: day)
        let b = snap(date: tomorrow)
        XCTAssertTrue(SessionDuplicate.pairs(in: [a, b], calendar: calendar).isEmpty)
    }
}
