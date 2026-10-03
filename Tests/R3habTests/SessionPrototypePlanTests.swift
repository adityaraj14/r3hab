import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class SessionPrototypePlanTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var day0: Date {
        calendar.startOfDay(for: Date(timeIntervalSince1970: 1_777_766_400))
    }

    func testEmptyHistoryPrefillsThreeByEight() {
        let draft = SessionPrototypePlan.make(
            sessions: [],
            phase: .cHeavySlowResistance,
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(draft.exerciseTitle, "Seated leg extension")
        XCTAssertEqual(draft.sessionType, .hsrStrength)
        XCTAssertEqual(draft.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: nil))
        XCTAssertEqual(draft.sets.count, 3)
        XCTAssertTrue(draft.sets.allSatisfy { $0.matchesTarget(draft.target) })
        XCTAssertEqual(draft.planLine, "3×8")
        XCTAssertEqual(draft.quickQuestion, "Did you do today's plan: 3×8?")
        XCTAssertFalse(draft.includeWarmup)
        XCTAssertTrue(draft.whatIDid().hasPrefix("Seated leg extension"))
    }

    func testPrefillCopiesSeatedExtensionTargetLoad() {
        let prior = session(dayOffset: -3, reps: 8, load: 45)
        let draft = SessionPrototypePlan.make(
            sessions: [prior],
            phase: .cHeavySlowResistance,
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(draft.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 45))
        XCTAssertEqual(draft.sets.count, 3)
        XCTAssertTrue(draft.sets.allSatisfy { $0.reps == 8 && $0.loadLbs == 45 })
        XCTAssertEqual(draft.planLine, "3×8 @ 45 lb")
        XCTAssertEqual(draft.quickQuestion, "Did you do today's plan: 3×8 @ 45 lb?")
        XCTAssertEqual(draft.stanceLabel, "Hold the load")
        let work = draft.resistanceSets().filter { !$0.isWarmup }
        XCTAssertEqual(work.count, 6)
        XCTAssertTrue(work.allSatisfy { $0.loadLbs == 45 && $0.reps == 8 })
    }

    func testSameAsTargetRestoresEdits() {
        var draft = SessionPrototypePlan.make(
            sessions: [session(dayOffset: -3, reps: 8, load: 45)],
            phase: .aFlareDeLoad,
            asOf: day0,
            calendar: calendar
        )
        draft.sets[0].reps = 12
        draft.sets[0].loadLbs = 55
        XCTAssertFalse(draft.sets[0].matchesTarget(draft.target))
        draft.sets[0] = draft.sets[0].aligned(to: draft.target)
        XCTAssertTrue(draft.sets[0].matchesTarget(draft.target))
        XCTAssertEqual(draft.phase, .aFlareDeLoad)
    }

    func testWarmupAndPainUseTheSessionSaveShape() throws {
        var draft = SessionPrototypePlan.make(
            sessions: [session(dayOffset: -3, reps: 8, load: 45)],
            phase: .cHeavySlowResistance,
            asOf: day0,
            calendar: calendar
        )
        draft.includeWarmup = true
        draft.painDuring = 2
        let saved = SessionPrototypePlan.setsForSave(draft)
        let warmup = saved.filter(\.isWarmup)
        let work = saved.filter { !$0.isWarmup }
        // No past warm-up, so the template from today's load is used.
        XCTAssertEqual(draft.warmup.source, .template)
        let working = try XCTUnwrap(draft.target.loadLbs)
        XCTAssertEqual(warmup.count, 3)
        XCTAssertEqual(warmup[0].holdSeconds, 30)
        XCTAssertEqual(warmup[0].reps, 1)
        XCTAssertNil(warmup[0].loadLbs)
        XCTAssertEqual(warmup[1].reps, 3)
        XCTAssertEqual(warmup[1].loadLbs, WarmupPlan.roundLoad(working * 0.5, step: 5))
        XCTAssertEqual(warmup[2].reps, 2)
        XCTAssertEqual(warmup[2].loadLbs, WarmupPlan.roundLoad(working * 0.75, step: 5))
        XCTAssertTrue(warmup.allSatisfy { $0.painDuring == nil })
        XCTAssertEqual(work.count, 6)
        XCTAssertTrue(work.allSatisfy { $0.painDuring == 2 })
        XCTAssertTrue(draft.whatIDid().contains("Seated leg extension"))
        XCTAssertTrue(draft.whatIDid().contains("Warm-up"))
    }

    func testGuidedStepsCoverTheQuestions() {
        let prompts = SessionPrototypePlan.guidedPrompts(setCount: 3)
        XCTAssertEqual(prompts, [
            .exercise, .warmup, .set(0), .set(1), .set(2), .pain, .notes, .review
        ])
        XCTAssertEqual(GuidedPrompt.set(0).accessibilityIdentifier, "prototype-guided-set-1")
        XCTAssertEqual(SessionPrototypeAccessibility.screen(.guided), "prototype-guided-screen")
        XCTAssertEqual(SessionPrototypeAccessibility.open(.live), "prototype-open-live")
        XCTAssertEqual(SessionPrototypeAccessibility.painChip(2), "prototype-pain-chip-2")
        XCTAssertEqual(SessionPrototypeAccessibility.quickYes, "prototype-quick-yes")
        XCTAssertEqual(SessionPrototypeAccessibility.liveDone, "prototype-live-done-set")
    }

    func testChoiceChipsIncludeTheTarget() {
        XCTAssertEqual(SessionPrototypePlan.repChoices(around: 9), [6, 8, 9, 10, 12, 15])
        let loads: [Double?] = [35, 40, 45, 50, 55]
        XCTAssertEqual(SessionPrototypePlan.loadChoices(around: 45), loads)
        XCTAssertEqual(SessionPrototypePlan.loadChoices(around: nil), [nil, 10, 20, 30, 40, 50])
        XCTAssertEqual(SessionPrototypePlan.bumpReps(1, by: -1), 1)
        XCTAssertEqual(SessionPrototypePlan.bumpLoad(nil, by: 5), 5)
        XCTAssertNil(SessionPrototypePlan.bumpLoad(nil, by: -5))
        XCTAssertEqual(SessionPrototypePlan.bumpLoad(5, by: -5), 0)
    }

    func testDialAndRulerMath() {
        XCTAssertEqual(SessionPrototypePlan.reps(8, ticks: 2), 10)
        XCTAssertEqual(SessionPrototypePlan.reps(1, ticks: -3), 1)
        XCTAssertEqual(SessionPrototypePlan.reps(29, ticks: 5), SessionPrototypePlan.maxReps)
        XCTAssertEqual(SessionPrototypePlan.load(45, ticks: 1), 50)
        XCTAssertEqual(SessionPrototypePlan.load(nil, ticks: 2), 10)
        XCTAssertNil(SessionPrototypePlan.load(5, ticks: -1))
        XCTAssertNil(SessionPrototypePlan.load(nil, ticks: -1))
        XCTAssertEqual(SessionPrototypePlan.load(295, ticks: 4), SessionPrototypePlan.maxLoad)
        XCTAssertEqual(SessionPrototypePlan.loadIndex(45), 9)
        XCTAssertEqual(SessionPrototypePlan.loadIndex(nil), 0)
        XCTAssertEqual(SessionPrototypePlan.load(atIndex: 9), 45)
        XCTAssertNil(SessionPrototypePlan.load(atIndex: 0))
        XCTAssertEqual(SessionPrototypePlan.loadIndexCount, 61)
        XCTAssertEqual(SessionPrototypePlan.repsDelta(8, target: 8), "Target")
        XCTAssertEqual(SessionPrototypePlan.repsDelta(10, target: 8), "+2 reps")
        XCTAssertEqual(SessionPrototypePlan.repsDelta(7, target: 8), "\u{2212}1 rep")
        XCTAssertEqual(SessionPrototypePlan.loadDelta(50, target: 45), "+5 lb")
        XCTAssertEqual(SessionPrototypePlan.loadDelta(35, target: 45), "\u{2212}10 lb")
        XCTAssertEqual(SessionPrototypePlan.loadDelta(nil, target: nil), "Target")
    }

    func testSetsOpenAtTheRecommendation() {
        let draft = SessionPrototypePlan.make(
            sessions: [session(dayOffset: -3, reps: 8, load: 45)],
            phase: .cHeavySlowResistance,
            asOf: day0,
            calendar: calendar
        )
        XCTAssertFalse(draft.sets.isEmpty)
        XCTAssertTrue(draft.sets.allSatisfy { $0.matchesTarget(draft.target) })
    }

    private func session(dayOffset: Int, reps: Int, load: Double) -> TrainingSessionSnapshot {
        let date = calendar.date(byAdding: .day, value: dayOffset, to: day0)!
        let rows = SessionPrefill.workSets(
            from: LoadPrescription(workingSets: 3, reps: reps, loadLbs: load),
            laterality: .bilateral
        )
        return TrainingSessionSnapshot(
            date: date,
            createdAt: date.addingTimeInterval(60),
            sessionType: .hsrStrength,
            response24h: .same,
            decision: .stay,
            resolvedAt: date.addingTimeInterval(86_400),
            snoozedUntil: nil,
            phase: .cHeavySlowResistance,
            painDuring: 2,
            painAfter: 2,
            whatIDid: "Seated leg extension · 3×\(reps) @ \(LoadCopy.labeled(load))",
            resistanceSets: rows
        )
    }
}
