import XCTest
@testable import R3hab

final class WorkoutStreakTests: XCTestCase {
    private func snap(
        createdAt: Date,
        type: SessionType = .isometrics,
        date: Date? = nil
    ) -> TrainingSessionSnapshot {
        TrainingSessionSnapshot(
            id: UUID(),
            date: date ?? createdAt,
            createdAt: createdAt,
            sessionType: type,
            response24h: .pending,
            decision: nil,
            resolvedAt: nil,
            snoozedUntil: nil,
            phase: .bIsometrics
        )
    }

    func testEmptyHasZeroStreakAndNoMiss() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let result = WorkoutStreak.evaluate(sessions: [], now: now)
        XCTAssertEqual(result.current, 0)
        XCTAssertEqual(result.lastChain, 0)
        XCTAssertEqual(result.best, 0)
        XCTAssertEqual(result.miss, .none)
        XCTAssertNil(result.lastHardAt)
    }

    func testSingleHardSessionIsLiveWithin48h() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let created = now.addingTimeInterval(-10 * 3600)
        let result = WorkoutStreak.evaluate(sessions: [snap(createdAt: created)], now: now)
        XCTAssertEqual(result.current, 1)
        XCTAssertEqual(result.lastChain, 1)
        XCTAssertEqual(result.best, 1)
        XCTAssertEqual(result.miss, .none)
    }

    func testWithin48hChainCountsSuccessiveHardSessions() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = [
            snap(createdAt: now.addingTimeInterval(-70 * 3600)),
            snap(createdAt: now.addingTimeInterval(-30 * 3600)),
            snap(createdAt: now.addingTimeInterval(-4 * 3600))
        ]
        let result = WorkoutStreak.evaluate(sessions: sessions, now: now)
        XCTAssertEqual(result.current, 3)
        XCTAssertEqual(result.lastChain, 3)
        XCTAssertEqual(result.best, 3)
        XCTAssertEqual(result.miss, .none)
    }

    func testGapGreaterThan48hBreaksTheChain() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = [
            snap(createdAt: now.addingTimeInterval(-100 * 3600)),
            snap(createdAt: now.addingTimeInterval(-60 * 3600)),
            snap(createdAt: now.addingTimeInterval(-10 * 3600))
        ]
        let result = WorkoutStreak.evaluate(sessions: sessions, now: now)
        XCTAssertEqual(result.current, 1)
        XCTAssertEqual(result.lastChain, 1)
        XCTAssertEqual(result.best, 2)
    }

    func testOtherSessionsAreIgnored() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = [
            snap(createdAt: now.addingTimeInterval(-20 * 3600), type: .other),
            snap(createdAt: now.addingTimeInterval(-6 * 3600), type: .hsrStrength)
        ]
        let result = WorkoutStreak.evaluate(sessions: sessions, now: now)
        XCTAssertEqual(result.current, 1)
        XCTAssertEqual(result.best, 1)
    }

    func testSameDayDoublesEachCountAsALink() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let morning = now.addingTimeInterval(-8 * 3600)
        let evening = now.addingTimeInterval(-3 * 3600)
        let sessions = [
            snap(createdAt: morning, type: .isometrics, date: morning),
            snap(createdAt: evening, type: .hsrStrength, date: morning)
        ]
        let result = WorkoutStreak.evaluate(sessions: sessions, now: now)
        XCTAssertEqual(result.current, 2, "Two hard sessions the same day are two Process votes.")
    }

    func testLiveStreakDropsWhenNowIsPast48h() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sessions = [
            snap(createdAt: now.addingTimeInterval(-90 * 3600)),
            snap(createdAt: now.addingTimeInterval(-50 * 3600))
        ]
        let result = WorkoutStreak.evaluate(sessions: sessions, now: now)
        XCTAssertEqual(result.current, 0)
        XCTAssertEqual(result.lastChain, 2)
        XCTAssertEqual(result.miss, .oneMiss)
    }

    func testMissStates() {
        XCTAssertEqual(WorkoutStreak.missState(hoursSinceLastHard: 10), .none)
        XCTAssertEqual(WorkoutStreak.missState(hoursSinceLastHard: 40), .approaching)
        XCTAssertEqual(WorkoutStreak.missState(hoursSinceLastHard: 48), .approaching)
        XCTAssertEqual(WorkoutStreak.missState(hoursSinceLastHard: 48.01), .oneMiss)
        XCTAssertEqual(WorkoutStreak.missState(hoursSinceLastHard: 72), .oneMiss)
        XCTAssertEqual(WorkoutStreak.missState(hoursSinceLastHard: 96), .oneMiss)
        XCTAssertEqual(WorkoutStreak.missState(hoursSinceLastHard: 96.01), .twoMiss)
    }

    func testOneMissCopyMentionsDontMissTwice() {
        let copy = WorkoutStreak.copy(for: .oneMiss, lastChain: 3)
        XCTAssertEqual(copy?.title, "One miss is alright")
        XCTAssertTrue(copy?.body.contains("Don’t miss twice") == true)
        XCTAssertTrue(copy?.body.contains("3 sessions") == true)
        XCTAssertTrue(copy?.body.contains("Inspired by Atomic Habits") == true)
    }

    func testQuoteRotatesByDayAndTap() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 2))!
        XCTAssertEqual(MotivationalQuotes.dailyIndex(on: day1, calendar: calendar), 0)
        XCTAssertEqual(MotivationalQuotes.dailyIndex(on: day2, calendar: calendar), 1)

        let first = MotivationalQuotes.quote(dayIndex: 0, tapOffset: 0)
        let next = MotivationalQuotes.quote(dayIndex: 0, tapOffset: 1)
        XCTAssertNotEqual(first.text, next.text)
        XCTAssertEqual(MotivationalQuotes.all.count, 13)
        XCTAssertTrue(MotivationalQuotes.all.allSatisfy { $0.text.count < 160 })
    }
}
