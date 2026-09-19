import XCTest
@testable import R3hab

final class SessionDraftTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var today: Date {
        calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_100_000))
    }

    private func snap(
        date: Date? = nil,
        createdAt: Date? = nil,
        type: SessionType = .isometrics,
        response: Response24h = .pending,
        isDraft: Bool = false,
        painAfter: Int = PainScore.notLogged
    ) -> TrainingSessionSnapshot {
        let day = calendar.startOfDay(for: date ?? today)
        return TrainingSessionSnapshot(
            id: UUID(),
            date: day,
            createdAt: createdAt ?? day,
            sessionType: type,
            response24h: response,
            decision: nil,
            resolvedAt: nil,
            snoozedUntil: nil,
            phase: .bIsometrics,
            painDuring: isDraft ? PainScore.notLogged : 2,
            painAfter: painAfter,
            isDraft: isDraft
        )
    }

    private func session(isDraft: Bool, type: SessionType = .isometrics, date: Date? = nil) -> TrainingSession {
        let row = TrainingSession(
            date: date ?? today,
            phase: .bIsometrics,
            sessionType: type,
            whatIDid: "Seated extension",
            painDuring: isDraft ? PainScore.notLogged : 2,
            calendar: calendar
        )
        row.isDraft = isDraft
        return row
    }

    func testNewSessionDefaultsToComplete() {
        let row = TrainingSession(
            date: today,
            phase: .bIsometrics,
            sessionType: .isometrics,
            whatIDid: "Seated extension",
            painDuring: 2,
            calendar: calendar
        )
        XCTAssertFalse(row.isDraft)
        XCTAssertTrue(row.snapshot.isFinalized)
    }

    func testWorthSavingNeedsARealMark() {
        let seeded = [ResistanceSet(reps: 8, loadLbs: nil, holdSeconds: nil, isWarmup: false)]
        XCTAssertFalse(SessionDraft.isWorthSaving(painDuring: nil, notes: "  ", sets: seeded))
        XCTAssertTrue(SessionDraft.isWorthSaving(painDuring: 3, notes: "", sets: seeded))
        XCTAssertTrue(SessionDraft.isWorthSaving(painDuring: nil, notes: "halfway", sets: seeded))
        XCTAssertTrue(SessionDraft.isWorthSaving(
            painDuring: nil,
            notes: "",
            sets: [ResistanceSet(reps: 8, loadLbs: 25, holdSeconds: nil, isWarmup: false)]
        ))
    }

    func testOpenDraftPrefersPrimaryTypeThenAnyThatDay() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let iso = snap(type: .isometrics, isDraft: true)
        let hsr = snap(type: .hsrStrength, isDraft: true)
        let old = snap(date: yesterday, type: .isometrics, isDraft: true)
        let complete = snap(type: .isometrics, isDraft: false)

        XCTAssertEqual(
            SessionDraft.openDraftID(
                in: [hsr, iso, old, complete],
                on: today,
                preferring: .isometrics,
                calendar: calendar
            ),
            iso.id
        )
        XCTAssertEqual(
            SessionDraft.openDraftID(
                in: [hsr, old, complete],
                on: today,
                preferring: .isometrics,
                calendar: calendar
            ),
            hsr.id
        )
        XCTAssertNil(
            SessionDraft.openDraftID(
                in: [old, complete],
                on: today,
                preferring: .isometrics,
                calendar: calendar
            )
        )
    }

    func testStreakIgnoresAHardDraft() {
        let complete = snap(isDraft: false)
        let draft = snap(createdAt: today.addingTimeInterval(60), isDraft: true)
        let onlyDraft = WorkoutStreak.evaluate(sessions: [draft], now: today, calendar: calendar)
        XCTAssertEqual(onlyDraft.current, 0)
        XCTAssertNil(onlyDraft.lastHardDay)

        let mixed = WorkoutStreak.evaluate(sessions: [complete, draft], now: today, calendar: calendar)
        XCTAssertEqual(mixed.current, 1)
    }

    func testTrainedTodayIgnoresDrafts() {
        XCTAssertFalse(
            TodayPlanner.trainedToday(sessions: [snap(isDraft: true)], now: today, calendar: calendar)
        )
        XCTAssertTrue(
            TodayPlanner.trainedToday(
                sessions: [snap(isDraft: true), snap(isDraft: false)],
                now: today,
                calendar: calendar
            )
        )
    }

    func testAfterPainQueueIgnoresDrafts() {
        let draft = snap(isDraft: true)
        let complete = snap(createdAt: today.addingTimeInterval(30), isDraft: false)
        let ids = TodayPlanner.recentMissingAfterPain(sessions: [draft, complete], now: today)
        XCTAssertEqual(ids, [complete.id])
    }

    func testPendingQueueIgnoresDrafts() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let draftToday = snap(isDraft: true)
        let draftOverdue = snap(date: yesterday, isDraft: true)
        let completeOverdue = snap(date: yesterday, isDraft: false)
        let completeToday = snap(isDraft: false)

        XCTAssertEqual(
            PendingQueue.overdue(
                sessions: [draftToday, draftOverdue, completeOverdue],
                now: today,
                calendar: calendar
            ).map(\.id),
            [completeOverdue.id]
        )
        XCTAssertEqual(
            PendingQueue.todayPending(
                sessions: [draftToday, completeToday],
                now: today,
                calendar: calendar
            ).map(\.id),
            [completeToday.id]
        )
    }

    func testSpacingIgnoresDrafts() {
        let draft = snap(createdAt: today.addingTimeInterval(-3600), isDraft: true)
        XCTAssertFalse(
            SessionSpacing.shouldWarnUnder48h(
                sessions: [draft],
                newType: .isometrics,
                now: today,
                excluding: nil
            )
        )
        let complete = snap(createdAt: today.addingTimeInterval(-3600), isDraft: false)
        XCTAssertTrue(
            SessionSpacing.shouldWarnUnder48h(
                sessions: [complete],
                newType: .isometrics,
                now: today,
                excluding: nil
            )
        )
    }

    @MainActor
    func testNotificationsIgnoreDrafts() {
        let draft = session(isDraft: true)
        let complete = session(isDraft: false)
        XCTAssertEqual(LogStore.pendingSessionTuples(from: [draft, complete]).map(\.id), [complete.id])
        XCTAssertEqual(LogStore.painAfterSessionTuples(from: [draft, complete]).map(\.id), [complete.id])
        XCTAssertEqual(LogStore.lastHardDate(from: [draft]), nil)
        XCTAssertEqual(LogStore.lastHardDate(from: [draft, complete]), complete.date)
    }

    func testFinalizedDropsDraftRows() {
        let draft = snap(isDraft: true)
        let complete = snap(isDraft: false)
        XCTAssertEqual(SessionDraft.finalized([draft, complete]).map(\.id), [complete.id])
    }
}
