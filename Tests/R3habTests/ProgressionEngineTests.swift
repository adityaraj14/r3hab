import XCTest
#if canImport(R3hab)
@testable import R3hab
#else
@testable import R3habDomain
#endif

final class ProgressionEngineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var day0: Date {
        calendar.startOfDay(for: Date(timeIntervalSince1970: 1_777_766_400))
    }

    func testEmptyHistoryHoldsDefaultThreeByEight() {
        let result = ProgressionEngine.today(
            sessions: [],
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: nil))
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.stance.label, "Hold the load")
        XCTAssertEqual(result.reason, ProgressionEngine.reasonStart)
        XCTAssertFalse(result.reason.isEmpty)
        XCTAssertEqual(result.blockedBy, [])
        XCTAssertNil(result.pendingResolveID)
    }

    func testTwoCleanHitsAdviseIncreaseAndPrefillTheIncreasedLoad() {
        let first = hsr(dayOffset: -4, sets: 3, reps: 8, load: 35, pain: 2, response: .better)
        let second = hsr(dayOffset: -2, sets: 3, reps: 8, load: 35, pain: 3, response: .same)
        let result = today([first, second])
        XCTAssertEqual(result.stance, .advance)
        XCTAssertEqual(result.stance.label, "Increase the load")
        XCTAssertEqual(result.reason, ProgressionEngine.reasonTwoCleanIncrease)
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 40))
        XCTAssertEqual(result.current.loadLbs, 35)
        XCTAssertEqual(result.suggestedChangeLoadLbs, 40)
        XCTAssertEqual(result.cardReason, "Increase the load. Try 40 lb.")
        XCTAssertFalse(result.cardReason.contains("Last time"))
        XCTAssertEqual(result.blockedBy, [])
        let prefill = SessionPrefill.workSets(from: result.target, laterality: .bilateral)
        XCTAssertTrue(prefill.allSatisfy { $0.loadLbs == 40 })
    }

    func testPainThreeInclusiveStillAdvances() {
        let first = hsr(dayOffset: -4, sets: 3, reps: 10, load: 35, pain: 3, response: .same)
        let second = hsr(dayOffset: -2, sets: 3, reps: 10, load: 35, pain: 3, response: .better)
        let result = today([first, second])
        XCTAssertEqual(result.stance, .advance)
        XCTAssertEqual(result.stance.label, "Increase the load")
        XCTAssertFalse(result.blockedBy.contains(.painDuring))
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 10, loadLbs: 40))
        XCTAssertEqual(result.reason, ProgressionEngine.reasonTwoCleanIncrease)
    }

    func testSameResponseAdvancesLikeBetter() {
        let first = hsr(dayOffset: -4, sets: 3, reps: 12, load: 50, pain: 1, response: .same)
        let second = hsr(dayOffset: -2, sets: 3, reps: 12, load: 50, pain: 0, response: .same)
        let result = today([first, second])
        XCTAssertEqual(result.stance, .advance)
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 12, loadLbs: 55))
    }

    func testAdvanceAddsOneIncrementToThePrefill() {
        let first = hsr(dayOffset: -4, sets: 3, reps: 10, load: 35, pain: 1)
        let second = hsr(dayOffset: -2, sets: 3, reps: 10, load: 35, pain: 1)
        let result = today([first, second])
        XCTAssertEqual(result.stance, .advance)
        XCTAssertEqual(result.target.loadLbs, 35 + ProgressionEngine.loadIncrementLbs)
        let sets = SessionPrefill.workSets(from: result.target, laterality: .bilateral)
        XCTAssertTrue(sets.allSatisfy { $0.loadLbs == 40 })
    }

    func testDropAdvisesDecreaseWithoutLoweringPrefill() {
        let hot = hsr(dayOffset: -2, sets: 3, reps: 10, load: 35, pain: 4, response: .better)
        let result = today([hot])
        XCTAssertEqual(result.stance, .drop)
        XCTAssertEqual(result.stance.label, "Decrease the load")
        XCTAssertEqual(result.target.loadLbs, 35)
        XCTAssertNotEqual(result.target.loadLbs, 30)
    }

    func testOneCleanHitHolds() {
        let only = hsr(dayOffset: -2, sets: 3, reps: 8, load: 35, pain: 2)
        let result = today([only])
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35))
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.stance.label, "Hold the load")
        XCTAssertEqual(result.reason, ProgressionEngine.reasonOneClean)
        XCTAssertNil(result.suggestedChangeLoadLbs)
        XCTAssertEqual(result.cardReason, ProgressionEngine.reasonOneClean)
        XCTAssertFalse(result.cardReason.contains("lbs"))
        XCTAssertEqual(result.blockedBy, [.consecutiveCleanHits])
    }

    func testMissedRepsHoldAtTheBandFloor() {
        let miss = hsr(dayOffset: -2, sets: 3, reps: 6, load: 35, pain: 2)
        let result = today([miss])
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35))
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.reason, ProgressionEngine.reasonShortReps)
        XCTAssertTrue(result.blockedBy.contains(.consecutiveCleanHits))
        XCTAssertFalse(result.blockedBy.contains(.painDuring))
    }

    func testPainDuringAboveThreeDropsLoad() {
        let hot = hsr(dayOffset: -2, sets: 3, reps: 10, load: 35, pain: 4, response: .better)
        let result = today([hot])
        XCTAssertEqual(result.stance, .drop)
        XCTAssertEqual(result.stance.label, "Decrease the load")
        XCTAssertEqual(result.reason, "The pain during the session was 4.")
        XCTAssertNil(result.suggestedChangeLoadLbs)
        XCTAssertEqual(result.cardReason, "The pain during the session was 4.")
        XCTAssertTrue(result.blockedBy.contains(.painDuring))
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 10, loadLbs: 35))
    }

    func testPainDuringSixKeepsLastLoad() {
        let hot = hsr(dayOffset: -2, sets: 3, reps: 10, load: 35, pain: 6, response: .same)
        let result = today([hot])
        XCTAssertEqual(result.stance, .drop)
        XCTAssertEqual(result.reason, "The pain during the session was 6.")
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 10, loadLbs: 35))
    }

    func testPerSetPainCanFailThePainGate() {
        var hot = hsr(dayOffset: -2, sets: 3, reps: 8, load: 35, pain: 2, response: .same)
        hot.resistanceSets = SessionPrefill.workSets(
            from: LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35),
            laterality: .bilateral
        )
        hot.resistanceSets[0].painDuring = 4
        let result = today([hot])
        XCTAssertEqual(result.stance, .drop)
        XCTAssertEqual(result.reason, "The pain during the session was 4.")
        XCTAssertTrue(result.blockedBy.contains(.painDuring))
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35))
    }

    func testWorseHoldsLoadAndSoftCutStaysAdvice() {
        let first = hsr(dayOffset: -4, sets: 3, reps: 10, load: 35, pain: 2, response: .worse)
        let second = hsr(dayOffset: -2, sets: 4, reps: 8, load: 35, pain: 3, response: .worse)
        let result = today([first, second])
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.reason, "The 24-hour response is Worse. Hold the load.")
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35))
        XCTAssertEqual(result.blockedBy, [.responseWorse])
        XCTAssertEqual(
            DecisionSuggester.suggest(response: .worse, recentResolvedNonRest: []),
            .softCut
        )
        XCTAssertEqual(
            DecisionSuggester.suggest(response: .worse, recentResolvedNonRest: [.worse]),
            .hardDrop
        )
        let advice = DecisionSuggester.guidance(for: .softCut)
        XCTAssertNotNil(advice)
        XCTAssertTrue(advice?.contains("Decrease the load") == true)
        XCTAssertEqual(result.target.loadLbs, result.current.loadLbs)
    }

    func testSaving24hClearsTheTodayResolvePrompt() {
        let waiting = hsr(dayOffset: -2, sets: 3, reps: 10, load: 35, pain: 1, response: .pending)
        let before = today([waiting])
        XCTAssertEqual(before.pendingResolveID, waiting.id)

        let asking = TodayPlanner.nextAction(
            TodayPlannerInput(
                hasMorningPain: true,
                hasEveningPain: true,
                overduePending: [waiting.id],
                trainedToday: true,
                isEvening: true
            )
        )
        XCTAssertEqual(asking, .resolvePending(sessionID: waiting.id, remaining: 0))

        // The session query can still say pending for a turn after Save.
        // The answer recorded by the sheet has to win immediately.
        let saved = TodayPendingGate.applying(resolved: [waiting.id: .better], to: [waiting])
        XCTAssertEqual(saved.first?.response24h, .better)
        let after = today(saved)
        XCTAssertNil(after.pendingResolveID)
        let cleared = TodayPlanner.nextAction(
            TodayPlannerInput(
                hasMorningPain: true,
                hasEveningPain: true,
                overduePending: saved.filter { $0.response24h == .pending }.map(\.id),
                trainedToday: true,
                isEvening: true
            )
        )
        if case .resolvePending = cleared {
            XCTFail("Resolve prompt stayed up after the 24h save")
        }

        var alreadyWorse = waiting
        alreadyWorse.response24h = .worse
        let caughtUp = TodayPendingGate.applying(resolved: [waiting.id: .better], to: [alreadyWorse])
        XCTAssertEqual(caughtUp.first?.response24h, .worse)

        XCTAssertEqual(
            TodayPendingGate.remainingOverrides(
                [waiting.id: .better],
                liveResponses: [waiting.id: .pending]
            )[waiting.id],
            .better
        )
        XCTAssertTrue(
            TodayPendingGate.remainingOverrides(
                [waiting.id: .better],
                liveResponses: [waiting.id: .better]
            ).isEmpty
        )
        XCTAssertEqual(
            TodayPendingGate.remainingOverrides([waiting.id: .better], liveResponses: [:])[waiting.id],
            .better
        )
    }

    func testMissing24hHoldsAndAsks() {
        let ready = hsr(dayOffset: -4, sets: 3, reps: 10, load: 35, pain: 1, response: .better)
        let waiting = hsr(dayOffset: -2, sets: 3, reps: 10, load: 35, pain: 1, response: .pending)
        let result = today([ready, waiting])
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.reason, "The 24-hour response is not recorded.")
        XCTAssertFalse(result.reason.isEmpty)
        XCTAssertEqual(result.blockedBy, [.awaiting24h])
        XCTAssertEqual(result.pendingResolveID, waiting.id)
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 10, loadLbs: 35))
        XCTAssertEqual(result.target.loadLbs, 35)
        XCTAssertNotEqual(result.stance, .advance)
    }

    func testPendingStillAsksWhenPainWouldOtherwiseAdvance() {
        let first = hsr(dayOffset: -4, sets: 3, reps: 8, load: 35, pain: 1, response: .same)
        let second = hsr(dayOffset: -2, sets: 3, reps: 8, load: 35, pain: 1, response: .pending)
        let result = today([first, second])
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.reason, ProgressionEngine.reasonWaitingOn24h)
        XCTAssertNotNil(result.pendingResolveID)
        XCTAssertEqual(result.target.loadLbs, 35)
    }

    func testNotApplicableHoldsWithoutAResolveCTA() {
        let session = hsr(dayOffset: -2, sets: 3, reps: 8, load: 35, pain: 1, response: .notApplicable)
        let result = today([session])
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.reason, ProgressionEngine.reasonNotApplicable)
        XCTAssertNil(result.pendingResolveID)
        XCTAssertEqual(result.target.loadLbs, 35)
    }

    func testMidLadderSnapsIntoBandAtSameLoad() {
        let threeByTen = today([hsr(dayOffset: -2, sets: 3, reps: 10, load: 35, pain: 2)])
        XCTAssertEqual(threeByTen.stance, .hold)
        XCTAssertEqual(threeByTen.target, LoadPrescription(workingSets: 3, reps: 10, loadLbs: 35))

        let fourByEight = today([hsr(dayOffset: -2, sets: 4, reps: 8, load: 35, pain: 2)])
        XCTAssertEqual(fourByEight.stance, .hold)
        XCTAssertEqual(fourByEight.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35))

        let fourByTwelve = today([hsr(dayOffset: -2, sets: 4, reps: 12, load: 50, pain: 1)])
        XCTAssertEqual(fourByTwelve.target, LoadPrescription(workingSets: 3, reps: 12, loadLbs: 50))

        let twenty = today([hsr(dayOffset: -2, sets: 3, reps: 20, load: 35, pain: 1)])
        XCTAssertEqual(twenty.target, LoadPrescription(workingSets: 3, reps: 12, loadLbs: 35))
        XCTAssertLessThanOrEqual(twenty.target.reps, ProgressionEngine.repHardMax)

        let fifteen = today([hsr(dayOffset: -2, sets: 3, reps: 15, load: 35, pain: 1)])
        XCTAssertEqual(fifteen.target, LoadPrescription(workingSets: 3, reps: 12, loadLbs: 35))
    }

    func testTwoCleanMidLadderSessionsStepLoadInsteadOfNextRung() {
        let first = hsr(dayOffset: -4, sets: 4, reps: 8, load: 35, pain: 2)
        let second = hsr(dayOffset: -2, sets: 4, reps: 10, load: 35, pain: 2)
        let result = today([first, second])
        XCTAssertEqual(result.stance, .advance)
        XCTAssertEqual(result.stance.label, "Increase the load")
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 10, loadLbs: 40))
    }

    func testUserHistoryPrefillsTheIncreasedLoadAndAdvisesIncrease() {
        let sessions = [
            hsr(dayOffset: -5, sets: 3, reps: 8, load: 35, pain: 2, response: .better),
            hsr(dayOffset: -3, sets: 3, reps: 8, load: 35, pain: 1, response: .same)
        ]
        let result = today(sessions)
        XCTAssertEqual(result.target.displayLine, "3×8 @ 40 lb")
        XCTAssertEqual(result.current.displayLine, "3×8 @ 35 lb")
        XCTAssertEqual(result.stance, .advance)
        XCTAssertEqual(result.stance.label, "Increase the load")
        XCTAssertEqual(result.reason, ProgressionEngine.reasonTwoCleanIncrease)
        XCTAssertEqual(result.cardReason, "Increase the load. Try 40 lb.")
        XCTAssertFalse(result.cardReason.contains("Last time"))
        XCTAssertEqual(result.laterality, .bilateral)
    }

    func testUnilateralSixRowsCountAsThreeSets() {
        let session = hsr(dayOffset: -2, sets: 3, reps: 8, load: 35, pain: 2, unilateral: true)
        XCTAssertEqual(session.resistanceSets.count, 6)
        XCTAssertEqual(
            ProgressionEngine.inferPrescription(session),
            LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35)
        )
    }

    func testPrefillBuildsEditableWorkingPairs() {
        let target = LoadPrescription(workingSets: 3, reps: 10, loadLbs: 35)
        let sets = SessionPrefill.workSets(from: target, laterality: .bilateral)
        XCTAssertEqual(sets.count, 6)
        XCTAssertTrue(sets.allSatisfy { $0.reps == 10 })
        XCTAssertTrue(sets.allSatisfy { $0.loadLbs == 35 })
        XCTAssertTrue(sets.allSatisfy { $0.painDuring == nil })
        XCTAssertEqual(SessionSummary.groupWorkSets(sets).count, 3)
    }

    func testSaveCopiesSessionPainOntoSetsWithoutPain() {
        let seeded = SessionPrefill.workSets(
            from: LoadPrescription(workingSets: 3, reps: 10, loadLbs: 35),
            laterality: .bilateral
        )
        var seededWithOne = seeded
        seededWithOne[0].painDuring = 4
        let saved = ProgressionEngine.applySessionPain(2, to: seededWithOne)
        XCTAssertEqual(saved[0].painDuring, 4)
        XCTAssertTrue(saved.dropFirst().allSatisfy { $0.painDuring == 2 })
    }

    func testLegacyResistanceSetJSONDecodesWithoutPain() throws {
        let json = """
        [{"id":"00000000-0000-0000-0000-000000000001","reps":8,"loadLbs":35,"isWarmup":false,"side":"left"}]
        """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode([ResistanceSet].self, from: data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].reps, 8)
        XCTAssertEqual(decoded[0].loadLbs, 35)
        XCTAssertNil(decoded[0].painDuring)
    }

    func testIgnoresIsometricAndDraftSessions() {
        let iso = session(
            dayOffset: -2,
            type: .isometrics,
            sets: 3,
            reps: 8,
            load: 20,
            pain: 1
        )
        let draft = hsr(dayOffset: -1, sets: 4, reps: 12, load: 40, pain: 1)
        var draftCopy = draft
        draftCopy.isDraft = true
        let live = hsr(dayOffset: -3, sets: 3, reps: 8, load: 35, pain: 2)
        let result = today([iso, draftCopy, live])
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 35))
        XCTAssertEqual(result.stance, .hold)
        XCTAssertEqual(result.reason, ProgressionEngine.reasonOneClean)
    }

    func testLegacyShortNameStillCountsAsSeatedLegExtension() {
        var legacy = hsr(dayOffset: -4, sets: 3, reps: 8, load: 35, pain: 2)
        legacy.whatIDid = "\(PrimaryLoadCatalog.legacySeatedExtensionDisplayName) · 3×8 @ 35 lbs"
        var renamed = hsr(dayOffset: -2, sets: 3, reps: 8, load: 35, pain: 1)
        renamed.whatIDid = "\(PrimaryLoadCatalog.seatedExtension.title) · 3×8 @ 35 lbs"
        let oldHold = TrainingSessionSnapshot(
            date: day(-6),
            createdAt: day(-6),
            sessionType: .isometrics,
            response24h: .same,
            decision: .stay,
            resolvedAt: nil,
            snoozedUntil: nil,
            phase: .bIsometrics,
            whatIDid: "\(PrimaryLoadCatalog.legacySeatedExtensionDisplayName) hold ~60°"
        )
        let newHold = TrainingSessionSnapshot(
            date: day(-5),
            createdAt: day(-5),
            sessionType: .isometrics,
            response24h: .same,
            decision: .stay,
            resolvedAt: nil,
            snoozedUntil: nil,
            phase: .bIsometrics,
            whatIDid: "Seated leg extension hold ~60°"
        )
        let title = PrimaryLoadCatalog.seatedExtension.title
        XCTAssertTrue(ProgressionEngine.matchesPrimaryLoad(legacy, title: title))
        XCTAssertTrue(ProgressionEngine.matchesPrimaryLoad(renamed, title: title))
        XCTAssertTrue(ProgressionEngine.matchesPrimaryLoad(oldHold, title: title))
        XCTAssertTrue(ProgressionEngine.matchesPrimaryLoad(newHold, title: title))
        XCTAssertFalse(ProgressionEngine.matchesPrimaryLoad(legacy, title: PrimaryLoadCatalog.legPress.title))

        let result = today([legacy, renamed])
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 40))
        XCTAssertEqual(result.stance, .advance)
    }

    func testEvaluateAfterSaveAdvancesWhenTheNewSessionCompletesThePair() {
        let first = hsr(dayOffset: -3, sets: 3, reps: 8, load: 35, pain: 2)
        let second = hsr(dayOffset: -1, sets: 3, reps: 8, load: 35, pain: 2)
        let after = ProgressionEngine.evaluateAfterSave(
            sessions: [first, second],
            asOf: day0,
            calendar: calendar
        )
        XCTAssertEqual(after.stance, .advance)
        XCTAssertEqual(after.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 40))
        XCTAssertEqual(after.reason, ProgressionEngine.reasonTwoCleanIncrease)
    }

    func testCardReasonNamesOnlyADistinctSuggestedWeight() {
        let increase = ProgressionResult(
            target: LoadPrescription(workingSets: 3, reps: 8, loadLbs: 50),
            current: LoadPrescription(workingSets: 3, reps: 8, loadLbs: 45),
            stance: .advance,
            reason: ProgressionEngine.reasonTwoCleanIncrease,
            blockedBy: [],
            laterality: .bilateral,
            pendingResolveID: nil
        )
        XCTAssertEqual(increase.suggestedChangeLoadLbs, 50)
        XCTAssertEqual(increase.cardReason, "Increase the load. Try 50 lb.")

        let decrease = ProgressionResult(
            target: LoadPrescription(workingSets: 3, reps: 8, loadLbs: 40),
            current: LoadPrescription(workingSets: 3, reps: 8, loadLbs: 45),
            stance: .drop,
            reason: ProgressionEngine.reasonPain(4),
            blockedBy: [.painDuring],
            laterality: .bilateral,
            pendingResolveID: nil
        )
        XCTAssertEqual(decrease.suggestedChangeLoadLbs, 40)
        XCTAssertEqual(decrease.cardReason, "Decrease the load. Try 40 lb.")

        let hold = ProgressionResult(
            target: LoadPrescription(workingSets: 3, reps: 8, loadLbs: 50),
            current: LoadPrescription(workingSets: 3, reps: 8, loadLbs: 45),
            stance: .hold,
            reason: ProgressionEngine.reasonOneClean,
            blockedBy: [.consecutiveCleanHits],
            laterality: .bilateral,
            pendingResolveID: nil
        )
        XCTAssertNil(hold.suggestedChangeLoadLbs)
        XCTAssertEqual(hold.cardReason, ProgressionEngine.reasonOneClean)

        let noLoad = ProgressionResult(
            target: LoadPrescription(workingSets: 3, reps: 8, loadLbs: nil),
            current: LoadPrescription(workingSets: 3, reps: 8, loadLbs: 45),
            stance: .advance,
            reason: ProgressionEngine.reasonTwoCleanIncrease,
            blockedBy: [],
            laterality: .bilateral,
            pendingResolveID: nil
        )
        XCTAssertNil(noLoad.suggestedChangeLoadLbs)
        XCTAssertEqual(noLoad.cardReason, ProgressionEngine.reasonTwoCleanIncrease)
    }

    func testDropStanceLabel() {
        XCTAssertEqual(ProgressionStance.drop.label, "Decrease the load")
        XCTAssertEqual(ProgressionStance.advance.label, "Increase the load")
        XCTAssertEqual(ProgressionStance.hold.label, "Hold the load")
    }

    func testPainAboveThreeWinsOverAMissingResolve() {
        let hot = hsr(dayOffset: -1, sets: 3, reps: 8, load: 40, pain: 5, response: .pending)
        let result = today([hot])
        XCTAssertEqual(result.stance, .drop)
        XCTAssertEqual(result.reason, "The pain during the session was 5.")
        XCTAssertEqual(result.pendingResolveID, hot.id)
        XCTAssertEqual(result.target, LoadPrescription(workingSets: 3, reps: 8, loadLbs: 40))
    }

    private func today(_ sessions: [TrainingSessionSnapshot]) -> ProgressionResult {
        let result = ProgressionEngine.today(
            sessions: sessions,
            asOf: day0,
            calendar: calendar
        )
        XCTAssertFalse(result.reason.isEmpty)
        return result
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: day0)!
    }

    private func hsr(
        dayOffset: Int,
        sets: Int,
        reps: Int,
        load: Double,
        pain: Int,
        unilateral: Bool = false,
        response: Response24h = .same
    ) -> TrainingSessionSnapshot {
        session(
            dayOffset: dayOffset,
            type: .hsrStrength,
            sets: sets,
            reps: reps,
            load: load,
            pain: pain,
            unilateral: unilateral,
            response: response
        )
    }

    private func session(
        dayOffset: Int,
        type: SessionType,
        sets: Int,
        reps: Int,
        load: Double,
        pain: Int,
        unilateral: Bool = false,
        response: Response24h = .same
    ) -> TrainingSessionSnapshot {
        let date = day(dayOffset)
        let target = LoadPrescription(workingSets: sets, reps: reps, loadLbs: load)
        var rows = SessionPrefill.workSets(from: target, laterality: .bilateral)
        if unilateral {
            for index in rows.indices where rows[index].side == .right {
                rows[index].loadLbs = load
            }
        }
        let resolvedAt: Date? = response == .pending ? nil : date.addingTimeInterval(86_400)
        return TrainingSessionSnapshot(
            date: date,
            createdAt: date.addingTimeInterval(60),
            sessionType: type,
            response24h: response,
            decision: response == .pending ? nil : .stay,
            resolvedAt: resolvedAt,
            snoozedUntil: nil,
            phase: .cHeavySlowResistance,
            painDuring: pain,
            painAfter: pain,
            whatIDid: "\(PrimaryLoadCatalog.seatedExtension.title) · \(sets)×\(reps) @ \(LoadCopy.labeled(load))",
            resistanceSets: rows
        )
    }
}
