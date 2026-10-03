import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

/// Regression: a draft saved with no pain-during score was counted as a
/// complete session, so Today asked for the pain after and the 24-hour response.
/// A session is complete only after the final save, with a pain-during score.
final class SessionCompletionTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var day0: Date {
        calendar.startOfDay(for: Date(timeIntervalSince1970: 1_777_766_400))
    }

    private var noon: Date { day0.addingTimeInterval(12 * 3600) }

    func testCompletionRule() {
        XCTAssertTrue(SessionCompletion.isComplete(isDraft: false, painDuring: 0))
        XCTAssertTrue(SessionCompletion.isComplete(isDraft: false, painDuring: 10))
        XCTAssertFalse(SessionCompletion.isComplete(isDraft: true, painDuring: 3))
        XCTAssertFalse(SessionCompletion.isComplete(isDraft: true, painDuring: PainScore.notLogged))
        XCTAssertFalse(SessionCompletion.isComplete(isDraft: false, painDuring: PainScore.notLogged))
    }

    /// The guided "Save draft" with no pain value, as Today reads it.
    func testDraftWithoutPainNeverAsksForPainAfterOr24h() {
        var guided = SessionPrototypePlan.make(
            sessions: [],
            phase: .cHeavySlowResistance,
            asOf: day0,
            calendar: calendar
        )
        guided.sets[0].loadLbs = 40
        XCTAssertNil(guided.painDuring)
        let checkpoint = GuidedCheckpointing.checkpoint(guided, stepIndex: 3)
        XCTAssertEqual(checkpoint.painDuring, PainScore.notLogged)
        let draft = row(from: checkpoint, isDraft: true)
        assertNotComplete([draft])
    }

    /// Defense in depth: a row with no pain-during score is not complete even
    /// if its draft flag is false (for example a row written before the flag was set).
    func testRowWithoutPainIsNotCompleteEvenIfNotFlaggedAsDraft() {
        let checkpoint = GuidedCheckpointing.checkpoint(
            SessionPrototypePlan.make(sessions: [], phase: .cHeavySlowResistance, asOf: day0, calendar: calendar),
            stepIndex: 2
        )
        assertNotComplete([row(from: checkpoint, isDraft: false)])
    }

    /// The final save with pain makes the same row complete, and the 24h and
    /// pain-after prompts start as before.
    func testFinalSaveWithPainCountsAsComplete() {
        var guided = SessionPrototypePlan.make(
            sessions: [],
            phase: .cHeavySlowResistance,
            asOf: day0,
            calendar: calendar
        )
        guided.sets = guided.sets.map { var set = $0; set.loadLbs = 40; return set }
        guided.painDuring = 2
        let session = TrainingSessionSnapshot(
            date: day0,
            createdAt: noon,
            sessionType: guided.sessionType,
            response24h: .pending,
            decision: nil,
            resolvedAt: nil,
            snoozedUntil: nil,
            phase: guided.phase,
            painDuring: 2,
            isDraft: false,
            whatIDid: guided.whatIDid(),
            resistanceSets: SessionPrototypePlan.setsForSave(guided)
        )
        let now = noon.addingTimeInterval(600)
        XCTAssertTrue(session.isFinalized)
        XCTAssertEqual(TodayPlanner.recentMissingAfterPain(sessions: [session], now: now), [session.id])
        XCTAssertTrue(TodayPlanner.trainedToday(sessions: [session], now: now, calendar: calendar))
        XCTAssertEqual(PendingQueue.todayPending(sessions: [session], now: now, calendar: calendar).map(\.id), [session.id])
        XCTAssertEqual(WorkoutStreak.evaluate(sessions: [session], now: now, calendar: calendar).current, 1)
        let progression = ProgressionEngine.today(
            sessions: [session],
            primaryLoadTitle: guided.exerciseTitle,
            asOf: now,
            calendar: calendar
        )
        XCTAssertEqual(progression.pendingResolveID, session.id)
    }

    private func assertNotComplete(_ sessions: [TrainingSessionSnapshot], file: StaticString = #filePath, line: UInt = #line) {
        let now = noon.addingTimeInterval(600)
        XCTAssertTrue(sessions.allSatisfy { !$0.isFinalized }, file: file, line: line)
        XCTAssertTrue(SessionDraft.finalized(sessions).isEmpty, file: file, line: line)
        XCTAssertTrue(TodayPlanner.recentMissingAfterPain(sessions: sessions, now: now).isEmpty, "No pain-after prompt", file: file, line: line)
        XCTAssertFalse(TodayPlanner.trainedToday(sessions: sessions, now: now, calendar: calendar), file: file, line: line)
        XCTAssertTrue(PendingQueue.todayPending(sessions: sessions, now: now, calendar: calendar).isEmpty, "No 24h prompt", file: file, line: line)
        let tomorrow = now.addingTimeInterval(36 * 3600)
        XCTAssertTrue(PendingQueue.overdue(sessions: sessions, now: tomorrow, calendar: calendar).isEmpty, file: file, line: line)
        XCTAssertEqual(WorkoutStreak.evaluate(sessions: sessions, now: now, calendar: calendar).current, 0, file: file, line: line)
        let progression = ProgressionEngine.today(
            sessions: sessions,
            primaryLoadTitle: PrimaryLoadCatalog.seatedExtension.title,
            asOf: now,
            calendar: calendar
        )
        XCTAssertNil(progression.pendingResolveID, "Next Up must not wait on a draft's 24h response", file: file, line: line)
        XCTAssertFalse(progression.blockedBy.contains(.awaiting24h), file: file, line: line)
    }

    private func row(from checkpoint: GuidedCheckpoint, isDraft: Bool) -> TrainingSessionSnapshot {
        TrainingSessionSnapshot(
            date: day0,
            createdAt: noon,
            sessionType: checkpoint.sessionType,
            response24h: .pending,
            decision: nil,
            resolvedAt: nil,
            snoozedUntil: nil,
            phase: checkpoint.phase,
            painDuring: checkpoint.painDuring,
            isDraft: isDraft,
            whatIDid: checkpoint.whatIDid,
            resistanceSets: checkpoint.resistanceSets
        )
    }
}
