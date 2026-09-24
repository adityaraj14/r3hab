import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class DecisionSuggesterTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private func session(
        id: UUID = UUID(),
        dayOffset: Int,
        from today: Date,
        response: Response24h,
        decision: SessionDecision? = .stay,
        createdOffset: TimeInterval = 0
    ) -> TrainingSessionSnapshot {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: today))!
        return TrainingSessionSnapshot(
            id: id,
            date: day,
            createdAt: day.addingTimeInterval(createdOffset),
            sessionType: .isometrics,
            response24h: response,
            decision: decision,
            resolvedAt: day.addingTimeInterval(86400),
            snoozedUntil: nil,
            phase: .bIsometrics
        )
    }

    func testBetterSuggestsStayWithoutCleanStreak() {
        let s = DecisionSuggester.suggest(response: .better, recentResolvedNonRest: [])
        XCTAssertEqual(s, .stay)
    }

    func testBetterSuggestsProgressAfterThreeClean() {
        let s = DecisionSuggester.suggest(
            response: .better,
            recentResolvedNonRest: [.same, .better, .same]
        )
        XCTAssertEqual(s, .progress)
    }

    func testFirstWorseIsSoftCut() {
        let s = DecisionSuggester.suggest(response: .worse, recentResolvedNonRest: [])
        XCTAssertEqual(s, .softCut)
    }

    func testSecondWorseIsHardDrop() {
        let s = DecisionSuggester.suggest(response: .worse, recentResolvedNonRest: [.worse])
        XCTAssertEqual(s, .hardDrop)
    }

    /// Multi-pending chronology vector from DESIGN (Mon/Wed/Fri).
    func testTwoWorseUsesSessionDateNotResolveOrder() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let mon = session(dayOffset: -4, from: today, response: .pending, decision: nil)
        let wed = session(dayOffset: -2, from: today, response: .pending, decision: nil)
        let fri = session(dayOffset: 0, from: today, response: .pending, decision: nil)

        // Resolve Wed first as Worse → SoftCut (Mon still pending)
        var wedResolved = wed
        wedResolved.response24h = .worse
        wedResolved.decision = .softCut
        let afterWed = DecisionSuggester.suggest(
            response: .worse,
            recentResolvedNonRest: DecisionSuggester.priorsForSuggestion(
                current: TrainingSessionSnapshot(
                    id: wed.id,
                    date: wed.date,
                    createdAt: wed.createdAt,
                    sessionType: .isometrics,
                    response24h: .worse,
                    decision: nil,
                    resolvedAt: nil,
                    snoozedUntil: nil,
                    phase: .bIsometrics
                ),
                all: [mon, wedResolved, fri]
            )
        )
        // When resolving Wed, mon is still pending so not in priors → SoftCut
        // Use unresolved mon+fri pending and only prior resolved empty:
        let suggestWed = DecisionSuggester.suggest(
            response: .worse,
            recentResolvedNonRest: DecisionSuggester.priorsForSuggestion(
                current: wed,
                all: [mon, wed, fri]
            )
        )
        XCTAssertEqual(suggestWed, .softCut)

        // After Mon+Wed both Worse resolved, Fri Worse → HardDrop (pred = Wed)
        var monResolved = mon
        monResolved.response24h = .worse
        monResolved.decision = .softCut
        let suggestFri = DecisionSuggester.suggest(
            response: .worse,
            recentResolvedNonRest: DecisionSuggester.priorsForSuggestion(
                current: fri,
                all: [monResolved, wedResolved, fri]
            )
        )
        XCTAssertEqual(suggestFri, .hardDrop)
        _ = afterWed
    }

    func testRestSessionsExcludedFromPriors() {
        let today = Date(timeIntervalSince1970: 1_700_000_000)
        let rest = session(dayOffset: -1, from: today, response: .notApplicable, decision: .rest)
        let current = session(dayOffset: 0, from: today, response: .pending, decision: nil)
        let priors = DecisionSuggester.priorsForSuggestion(current: current, all: [rest, current])
        XCTAssertTrue(priors.isEmpty)
    }
}

final class LoadNudgeEvaluatorTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private func day(_ offset: Int, from today: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: today))!
    }

    private func checkIn(dayOffset: Int, from today: Date, am: Int?) -> DailyCheckInSnapshot {
        DailyCheckInSnapshot(date: day(dayOffset, from: today), restingPainAM: am, steps: nil)
    }

    private func workout(
        id: UUID = UUID(),
        dayOffset: Int,
        from today: Date,
        response: Response24h,
        decision: SessionDecision? = .stay,
        createdOffset: TimeInterval = 0
    ) -> TrainingSessionSnapshot {
        let date = day(dayOffset, from: today)
        return TrainingSessionSnapshot(
            id: id,
            date: date,
            createdAt: date.addingTimeInterval(createdOffset),
            sessionType: .hsrStrength,
            response24h: response,
            decision: decision,
            resolvedAt: date.addingTimeInterval(86400),
            snoozedUntil: nil,
            phase: .cHeavySlowResistance
        )
    }

    func testMorningPainUpAfterYesterdayWorkoutNudgesEaseOff() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let nudge = LoadNudgeEvaluator.afterMorningPain(
            todayAM: 4,
            checkInDate: today,
            checkIns: [
                checkIn(dayOffset: -1, from: today, am: 2),
                checkIn(dayOffset: 0, from: today, am: 4)
            ],
            sessions: [workout(dayOffset: -1, from: today, response: .pending, decision: nil)],
            calendar: calendar
        )
        XCTAssertEqual(nudge, .easeOffMorning(previous: 2, current: 4))
    }

    func testMorningPainSameAsWorkoutMorningDoesNotNudge() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let nudge = LoadNudgeEvaluator.afterMorningPain(
            todayAM: 2,
            checkInDate: today,
            checkIns: [checkIn(dayOffset: -1, from: today, am: 2)],
            sessions: [workout(dayOffset: -1, from: today, response: .pending, decision: nil)],
            calendar: calendar
        )
        XCTAssertNil(nudge)
    }

    func testMorningPainIgnoresWorkoutTwoDaysAgo() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let nudge = LoadNudgeEvaluator.afterMorningPain(
            todayAM: 5,
            checkInDate: today,
            checkIns: [checkIn(dayOffset: -2, from: today, am: 2)],
            sessions: [workout(dayOffset: -2, from: today, response: .same)],
            calendar: calendar
        )
        XCTAssertNil(nudge)
    }

    func testWorseResolveNudgesEaseOff() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let current = workout(dayOffset: -1, from: today, response: .pending, decision: nil)
        XCTAssertEqual(
            LoadNudgeEvaluator.afterResolve(response: .worse, current: current, all: [current]),
            .easeOffWorse
        )
    }

    func testProgressCelebrationCopyFavorsWeight() {
        let nudge = LoadNudge.progress(cleanCount: 15)
        XCTAssertEqual(nudge.title, "Ready to add load")
        XCTAssertEqual(
            nudge.message,
            "Pain held steady — next time, try a bit more weight with the same sets and reps."
        )
        XCTAssertFalse(nudge.title.contains("Looks like you could progress"))
        XCTAssertFalse(nudge.message.contains("extra reps"))
        XCTAssertFalse(nudge.message.contains("longer hold"))
    }

    func testFifthCleanResolveNudgesProgress() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let priors = (-4...(-1)).map { offset in
            workout(dayOffset: offset, from: today, response: .same)
        }
        let current = workout(dayOffset: 0, from: today, response: .pending, decision: nil)
        XCTAssertEqual(
            LoadNudgeEvaluator.afterResolve(
                response: .better,
                current: current,
                all: priors + [current]
            ),
            .progress(cleanCount: 5)
        )
    }

    func testFourthCleanResolveDoesNotNudgeProgress() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let priors = (-3...(-1)).map { offset in
            workout(dayOffset: offset, from: today, response: .same)
        }
        let current = workout(dayOffset: 0, from: today, response: .pending, decision: nil)
        XCTAssertNil(
            LoadNudgeEvaluator.afterResolve(
                response: .same,
                current: current,
                all: priors + [current]
            )
        )
    }

    func testWorseBreaksCleanStreak() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let priors = [
            workout(dayOffset: -2, from: today, response: .worse, decision: .softCut),
            workout(dayOffset: -1, from: today, response: .same)
        ]
        let current = workout(dayOffset: 0, from: today, response: .pending, decision: nil)
        XCTAssertNil(
            LoadNudgeEvaluator.afterResolve(
                response: .better,
                current: current,
                all: priors + [current]
            )
        )
    }

    func testTenthCleanResolveNudgesAgain() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let priors = (-9...(-1)).map { offset in
            workout(dayOffset: offset, from: today, response: .same)
        }
        let current = workout(dayOffset: 0, from: today, response: .pending, decision: nil)
        XCTAssertEqual(
            LoadNudgeEvaluator.afterResolve(
                response: .same,
                current: current,
                all: priors + [current]
            ),
            .progress(cleanCount: 10)
        )
    }
}
