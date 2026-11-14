import XCTest
@testable import R3habDomain

final class TrainingLoadTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testIsometricVolumeUsesHoldsSecondsAndWeight() {
        let sets = [
            ResistanceSet(reps: 5, loadLbs: 40, holdSeconds: 45, isWarmup: false)
        ]
        let amount = TrainingLoad.amount(for: sets)
        XCTAssertEqual(amount.poundSeconds, 5 * 45 * 40)
        XCTAssertEqual(amount.poundReps, 0)
    }

    func testWorkingSetVolumeIsRepsTimesWeight() {
        let sets = (0..<4).map { _ in
            ResistanceSet(reps: 8, loadLbs: 140, isWarmup: false)
        }
        let amount = TrainingLoad.amount(for: sets)
        XCTAssertEqual(amount.poundReps, 4 * 8 * 140)
        XCTAssertEqual(amount.poundSeconds, 0)
    }

    func testWarmupIsLeftOut() {
        let sets = [
            ResistanceSet(reps: 10, loadLbs: 50, isWarmup: true),
            ResistanceSet(reps: 8, loadLbs: 100, isWarmup: false)
        ]
        XCTAssertEqual(TrainingLoad.amount(for: sets).poundReps, 800)
    }

    func testMatchedLeftAndRightCountOnce() {
        let sets = SessionSummary.makePair(reps: 8, loadLbs: 140, holdSeconds: nil, isWarmup: false)
        XCTAssertEqual(sets.count, 2)
        XCTAssertEqual(TrainingLoad.amount(for: sets).poundReps, 8 * 140)
    }

    func testDifferentLegLoadsBothCount() {
        let sets = SessionSummary.makePair(
            reps: 8,
            loadLbs: 100,
            holdSeconds: nil,
            isWarmup: false,
            rightLoadLbs: 80
        )
        XCTAssertEqual(TrainingLoad.amount(for: sets).poundReps, (8 * 100) + (8 * 80))
    }

    func testLegacyNamesClassifyOntoTheThreeExercises() {
        XCTAssertEqual(
            TrainingLoad.kind(sessionType: .isometrics, whatIDid: "Seated leg extension hold"),
            .isometricLegExtension
        )
        XCTAssertEqual(
            TrainingLoad.kind(sessionType: .hsrStrength, whatIDid: "Seated extension · 4×8 @ 140 lb"),
            .legExtensionHeavy
        )
        XCTAssertEqual(
            TrainingLoad.kind(sessionType: .hsrStrength, whatIDid: "Single-leg leg press"),
            .legPress
        )
        XCTAssertEqual(
            TrainingLoad.kind(sessionType: .isometrics, whatIDid: "Spanish squat"),
            .other
        )
    }

    func testSkippedExerciseIsNotSaved() {
        var exercises = GuidedSessionDraft.exercises(from: [])
        exercises[0].included = false
        exercises[1].loadLbs = 100
        exercises[1].pain = 2
        exercises[2].included = false
        let logs = GuidedSessionDraft.logs(from: exercises)
        XCTAssertEqual(logs.map(\.kind), [.legExtensionHeavy])
        XCTAssertEqual(TrainingLoad.amount(for: logs[0].sets).poundReps, 4 * 8 * 100)
    }

    func testIsometricSaveStoresHoldsOnOneRow() {
        var draft = ExerciseEntry.make(kind: .isometricLegExtension, from: [])
        draft.loadLbs = 35
        draft.sets = 5
        draft.holdSeconds = 45
        draft.pain = 1
        let sets = ExerciseEntry.resistanceSets(for: draft)
        XCTAssertEqual(sets.count, 1)
        XCTAssertEqual(sets[0].reps, 5)
        XCTAssertEqual(sets[0].holdSeconds, 45)
        XCTAssertEqual(TrainingLoad.amount(for: sets).poundSeconds, 5 * 45 * 35)
        XCTAssertNil(ExerciseEntry.issue(for: draft))
    }

    func testMissingPainBlocksSave() {
        var draft = ExerciseEntry.make(kind: .legPress, from: [])
        draft.loadLbs = 180
        XCTAssertNotNil(ExerciseEntry.issue(for: draft))
        draft.pain = 3
        XCTAssertNil(ExerciseEntry.issue(for: draft))
    }

    func testPrefillCountsAMatchedPairAsOneSet() {
        let paired = SessionSummary.makePair(reps: 8, loadLbs: 140, holdSeconds: nil, isWarmup: false)
        let logged = session(
            day: 1,
            type: .hsrStrength,
            what: "Seated leg extension",
            sets: paired
        )
        let draft = ExerciseEntry.make(kind: .legExtensionHeavy, from: [logged])
        XCTAssertEqual(draft.sets, 1)
        XCTAssertEqual(draft.reps, 8)
        XCTAssertEqual(draft.loadLbs, 140)
    }

    func testPrefillUsesTheLatestMatchingSession() {
        let older = session(
            day: 0,
            type: .hsrStrength,
            what: "Seated leg extension",
            sets: [ResistanceSet(reps: 10, loadLbs: 80, isWarmup: false)]
        )
        let newer = session(
            day: 2,
            type: .hsrStrength,
            what: "Seated leg extension",
            sets: [ResistanceSet(reps: 6, loadLbs: 120, isWarmup: false)]
        )
        let draft = ExerciseEntry.make(kind: .legExtensionHeavy, from: [older, newer])
        XCTAssertEqual(draft.loadLbs, 120)
        XCTAssertEqual(draft.reps, 6)
        XCTAssertEqual(draft.sets, 1)
    }

    func testPastSessionsGroupByDayAndKeepOtherWork() {
        let iso = session(
            day: 1,
            type: .isometrics,
            what: "Seated leg extension hold",
            sets: [ResistanceSet(reps: 4, loadLbs: 30, holdSeconds: 45, isWarmup: false)]
        )
        let press = session(
            day: 1,
            type: .hsrStrength,
            what: "Leg press",
            sets: (0..<3).map { _ in ResistanceSet(reps: 10, loadLbs: 200, isWarmup: false) },
            createdAtOffset: 60
        )
        let calf = session(
            day: 0,
            type: .other,
            what: "Calf raise",
            sets: [ResistanceSet(reps: 15, loadLbs: 0, isWarmup: false)]
        )
        let draft = session(
            day: 1,
            type: .hsrStrength,
            what: "Seated leg extension",
            sets: [ResistanceSet(reps: 8, loadLbs: 100, isWarmup: false)],
            isDraft: true
        )
        let days = SessionLogBuilder.days(from: [press, iso, calf, draft], calendar: calendar)
        XCTAssertEqual(days.count, 2)
        XCTAssertEqual(days[0].entries.map(\.kind), [.isometricLegExtension, .legPress])
        XCTAssertEqual(days[0].poundSeconds, 4 * 45 * 30)
        XCTAssertEqual(days[0].poundReps, 3 * 10 * 200)
        XCTAssertEqual(days[1].entries.map(\.title), ["Calf raise"])
    }

    func testTrendKeepsTheLatestDaysInOrder() {
        let days = (0..<10).map { offset in
            SessionLogDay(
                day: calendar.date(byAdding: .day, value: offset, to: Date(timeIntervalSince1970: 0))!,
                entries: [
                    SessionLogEntry(
                        id: UUID(),
                        createdAt: Date(timeIntervalSince1970: Double(offset)),
                        title: "Leg press working sets",
                        kind: .legPress,
                        dose: nil,
                        pain: "Pain 1",
                        poundReps: Double(offset + 1) * 100,
                        poundSeconds: 0
                    )
                ]
            )
        }
        let trend = SessionLogBuilder.workingSetTrend(from: days, limit: 8)
        XCTAssertEqual(trend.count, 8)
        XCTAssertEqual(trend.map(\.value), (3...10).map { Double($0) * 100 })
    }

    func testGuideHasTheFourStages() {
        XCTAssertEqual(
            RehabGuide.stages.map(\.title),
            [
                "Isometrics",
                "Isotonic / heavy slow resistance",
                "Energy storage / plyometrics",
                "Return to sport"
            ]
        )
        XCTAssertTrue(RehabGuide.stages.allSatisfy { !$0.purpose.isEmpty && $0.bullets.count >= 2 })
    }

    private func session(
        day: Int,
        type: SessionType,
        what: String,
        sets: [ResistanceSet],
        isDraft: Bool = false,
        createdAtOffset: TimeInterval = 0
    ) -> TrainingSessionSnapshot {
        let date = calendar.date(byAdding: .day, value: day, to: Date(timeIntervalSince1970: 1_700_000_000))!
        return TrainingSessionSnapshot(
            date: date,
            createdAt: date.addingTimeInterval(createdAtOffset),
            sessionType: type,
            response24h: .notApplicable,
            decision: nil,
            resolvedAt: nil,
            snoozedUntil: nil,
            phase: .heavySlow,
            painDuring: 2,
            isDraft: isDraft,
            whatIDid: what,
            resistanceSets: sets
        )
    }
}
