import XCTest
@testable import R3hab

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
