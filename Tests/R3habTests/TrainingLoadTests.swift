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
        let amount = TrainingLoad.amount(for: sets)
        XCTAssertEqual(amount.poundReps, (8 * 100) + (8 * 80))
        let lines = TrainingLoad.lines(for: sets)
        XCTAssertEqual(lines.map(\.text), ["8 reps @ 100 lb left, 80 lb right"])
        XCTAssertEqual(lines.reduce(0) { $0 + $1.poundReps }, amount.poundReps)
    }

    func testMatchedPairIsOneLineAndCountsOnce() {
        let sets = SessionSummary.makePair(reps: 8, loadLbs: 140, holdSeconds: nil, isWarmup: false)
        let lines = TrainingLoad.lines(for: sets)
        XCTAssertEqual(lines.map(\.text), ["8 reps @ 140 lb"])
        XCTAssertEqual(lines[0].poundReps, 8 * 140)
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

    func testDistinctHoldsSumSecondsTimesWeight() {
        let sets = [
            ResistanceSet(reps: 1, loadLbs: 40, holdSeconds: 45, isWarmup: false),
            ResistanceSet(reps: 1, loadLbs: 55, holdSeconds: 30, isWarmup: false)
        ]
        let amount = TrainingLoad.amount(for: sets)
        XCTAssertEqual(amount.poundSeconds, (45 * 40) + (30 * 55))
        let lines = TrainingLoad.lines(for: sets)
        XCTAssertEqual(lines.map(\.text), ["45s @ 40 lb", "30s @ 55 lb"])
        XCTAssertEqual(lines.reduce(0) { $0 + $1.poundSeconds }, amount.poundSeconds)
    }

    func testDistinctWorkingSetsSumRepsTimesWeight() {
        let sets = [
            ResistanceSet(reps: 8, loadLbs: 100, isWarmup: false),
            ResistanceSet(reps: 6, loadLbs: 120, isWarmup: false)
        ]
        let amount = TrainingLoad.amount(for: sets)
        XCTAssertEqual(amount.poundReps, (8 * 100) + (6 * 120))
        XCTAssertEqual(
            TrainingLoad.lines(for: sets).map(\.text),
            ["8 reps @ 100 lb", "6 reps @ 120 lb"]
        )
    }

    func testSkippedExerciseIsNotSaved() {
        var exercises = GuidedSessionDraft.exercises(from: [])
        exercises[0].included = false
        exercises[1].sets[0].loadLbs = 100
        exercises[1].pain = 2
        exercises[2].included = false
        let logs = GuidedSessionDraft.logs(from: exercises)
        XCTAssertEqual(logs.map(\.kind), [.legExtensionHeavy])
        XCTAssertEqual(logs[0].sets.count, 1)
        XCTAssertEqual(TrainingLoad.amount(for: logs[0].sets).poundReps, 8 * 100)
    }

    func testEachHoldSavesAsItsOwnRow() {
        var draft = ExerciseEntry.make(kind: .isometricLegExtension, from: [])
        draft.sets[0].loadLbs = 40
        draft.sets[0].holdSeconds = 45
        ExerciseEntry.duplicateLastSet(in: &draft)
        draft.sets[1].loadLbs = 55
        draft.sets[1].holdSeconds = 30
        draft.pain = 1
        let sets = ExerciseEntry.resistanceSets(for: draft)
        XCTAssertEqual(sets.count, 2)
        XCTAssertEqual(sets.map(\.reps), [1, 1])
        XCTAssertEqual(sets.map(\.holdSeconds), [45, 30])
        XCTAssertEqual(sets.map(\.loadLbs), [40, 55])
        XCTAssertEqual(TrainingLoad.amount(for: sets).poundSeconds, (45 * 40) + (30 * 55))
        XCTAssertNil(ExerciseEntry.issue(for: draft))
    }

    func testNextRequiresOneValidSetUnlessSkipped() {
        var draft = ExerciseEntry.make(kind: .legPress, from: [])
        ExerciseEntry.removeSet(draft.sets[0].id, from: &draft)
        draft.pain = 2
        XCTAssertEqual(ExerciseEntry.issue(for: draft), "Add a set, or skip this exercise.")
        ExerciseEntry.addSet(to: &draft)
        XCTAssertEqual(
            ExerciseEntry.issue(for: draft),
            "Enter a weight above 0 on every set, or skip this exercise."
        )
        draft.sets[0].loadLbs = 180
        XCTAssertNil(ExerciseEntry.issue(for: draft))
        draft.included = false
        draft.sets = []
        XCTAssertNil(ExerciseEntry.issue(for: draft))
    }

    func testAddStartsAFreshSetAndDuplicateCopiesTheLastOne() {
        var draft = ExerciseEntry.make(kind: .isometricLegExtension, from: [])
        draft.sets[0].loadLbs = 55
        draft.sets[0].holdSeconds = 30
        ExerciseEntry.addSet(to: &draft)
        XCTAssertEqual(draft.sets.count, 2)
        XCTAssertEqual(draft.sets[1].loadLbs, 55)
        XCTAssertEqual(draft.sets[1].holdSeconds, ExerciseEntry.defaultHoldSeconds)
        XCTAssertNotEqual(draft.sets[0].id, draft.sets[1].id)
        ExerciseEntry.duplicateLastSet(in: &draft)
        XCTAssertEqual(draft.sets[2].loadLbs, 55)
        XCTAssertEqual(draft.sets[2].holdSeconds, ExerciseEntry.defaultHoldSeconds)
        let id = draft.sets[0].id
        ExerciseEntry.removeSet(id, from: &draft)
        XCTAssertEqual(draft.sets.count, 2)
        XCTAssertFalse(draft.sets.contains { $0.id == id })
    }

    func testAddAndDuplicateStopAtTheSetCap() {
        var draft = ExerciseEntry.make(kind: .legPress, from: [])
        while draft.sets.count < ExerciseEntry.maxCount {
            ExerciseEntry.duplicateLastSet(in: &draft)
        }
        let count = draft.sets.count
        ExerciseEntry.addSet(to: &draft)
        ExerciseEntry.duplicateLastSet(in: &draft)
        XCTAssertEqual(draft.sets.count, count)
        XCTAssertEqual(count, ExerciseEntry.maxCount)
    }

    func testMissingPainBlocksSave() {
        var draft = ExerciseEntry.make(kind: .legPress, from: [])
        draft.sets[0].loadLbs = 180
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
        XCTAssertEqual(draft.sets.count, 1)
        XCTAssertEqual(draft.sets[0].reps, 8)
        XCTAssertEqual(draft.sets[0].loadLbs, 140)
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
            sets: [
                ResistanceSet(reps: 6, loadLbs: 120, isWarmup: false),
                ResistanceSet(reps: 4, loadLbs: 140, isWarmup: false)
            ]
        )
        let draft = ExerciseEntry.make(kind: .legExtensionHeavy, from: [older, newer])
        XCTAssertEqual(draft.sets.map(\.loadLbs), [120, 140])
        XCTAssertEqual(draft.sets.map(\.reps), [6, 4])
    }

    func testAggregateHoldRowExpandsWithoutChangingItsTotal() {
        let stored = [
            ResistanceSet(reps: 5, loadLbs: 40, holdSeconds: 45, isWarmup: false)
        ]
        let lines = TrainingLoad.lines(for: stored)
        XCTAssertEqual(lines.count, 5)
        XCTAssertTrue(lines.allSatisfy { $0.text == "45s @ 40 lb" })
        let amount = TrainingLoad.amount(for: stored)
        XCTAssertEqual(amount.poundSeconds, 5 * 45 * 40)
        XCTAssertEqual(lines.reduce(0) { $0 + $1.poundSeconds }, amount.poundSeconds)

        let logged = session(
            day: 1,
            type: .isometrics,
            what: "Seated leg extension hold",
            sets: stored
        )
        let draft = ExerciseEntry.make(kind: .isometricLegExtension, from: [logged])
        XCTAssertEqual(draft.sets.count, 5)
        XCTAssertTrue(draft.sets.allSatisfy { $0.holdSeconds == 45 && $0.loadLbs == 40 })
    }

    func testNovember12And13HoldAggregatesStillDisplay() {
        let nov12 = session(
            on: date(year: 2026, month: 11, day: 12),
            type: .isometrics,
            what: "Seated leg extension hold",
            sets: [ResistanceSet(reps: 2, loadLbs: 50, holdSeconds: 40, isWarmup: false)]
        )
        let nov13 = session(
            on: date(year: 2026, month: 11, day: 13),
            type: .isometrics,
            what: "Seated leg extension hold",
            sets: [ResistanceSet(reps: 3, loadLbs: 55, holdSeconds: 45, isWarmup: false)]
        )
        let days = SessionLogBuilder.days(from: [nov13, nov12], calendar: calendar)
        XCTAssertEqual(days.map { calendar.component(.day, from: $0.day) }, [13, 12])
        XCTAssertEqual(days[1].entries[0].setLines, ["40s @ 50 lb", "40s @ 50 lb"])
        XCTAssertEqual(days[1].poundSeconds, 2 * 40 * 50)
        XCTAssertEqual(days[0].entries[0].setLines.count, 3)
        XCTAssertEqual(days[0].poundSeconds, 3 * 45 * 55)
        XCTAssertEqual(
            days[0].entries[0].setLines.reduce(0) { $0 + ($1 == "45s @ 55 lb" ? 1 : 0) },
            3
        )
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
        XCTAssertEqual(days[0].entries[0].setLines, Array(repeating: "45s @ 30 lb", count: 4))
        XCTAssertEqual(days[0].poundSeconds, 4 * 45 * 30)
        XCTAssertEqual(days[0].entries[1].setLines.count, 3)
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
                        setLines: ["8 reps @ 100 lb"],
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

    func testComparisonKeepsAnAggregateHoldOnOneLine() {
        let sets = [
            ResistanceSet(reps: 2, loadLbs: 50, holdSeconds: 40, isWarmup: false)
        ]
        XCTAssertEqual(TrainingLoad.comparisonLines(for: sets), ["2 × 40s @ 50 lb"])
        let distinct = [
            ResistanceSet(reps: 1, loadLbs: 40, holdSeconds: 45, isWarmup: false),
            ResistanceSet(reps: 1, loadLbs: 55, holdSeconds: 30, isWarmup: false)
        ]
        XCTAssertEqual(
            TrainingLoad.comparisonLines(for: distinct),
            ["45s @ 40 lb", "30s @ 55 lb"]
        )
    }

    func testPriorExerciseIsTheLatestSavedSessionForThatExercise() {
        let older = session(
            on: date(year: 2026, month: 11, day: 12),
            type: .isometrics,
            what: "Seated leg extension hold",
            sets: [ResistanceSet(reps: 2, loadLbs: 50, holdSeconds: 40, isWarmup: false)]
        )
        let newer = session(
            on: date(year: 2026, month: 11, day: 13),
            type: .isometrics,
            what: "Seated leg extension hold",
            sets: [
                ResistanceSet(reps: 1, loadLbs: 40, holdSeconds: 45, isWarmup: false),
                ResistanceSet(reps: 1, loadLbs: 55, holdSeconds: 30, isWarmup: false)
            ]
        )
        let other = session(
            on: date(year: 2026, month: 11, day: 14),
            type: .hsrStrength,
            what: "Leg press",
            sets: [ResistanceSet(reps: 8, loadLbs: 200, isWarmup: false)]
        )
        let draft = session(
            on: date(year: 2026, month: 11, day: 14),
            type: .isometrics,
            what: "Seated leg extension hold",
            sets: [ResistanceSet(reps: 1, loadLbs: 70, holdSeconds: 20, isWarmup: false)],
            isDraft: true
        )
        let prior = PriorExerciseLookup.latest(
            kind: .isometricLegExtension,
            in: [older, other, draft, newer],
            calendar: calendar
        )
        XCTAssertEqual(prior?.lines, ["45s @ 40 lb", "30s @ 55 lb"])
        XCTAssertEqual(prior?.sets.map(\.loadLbs), [40, 55])
        XCTAssertEqual(prior?.sets.map(\.holdSeconds), [45, 30])
        let now = date(year: 2026, month: 11, day: 14)
        XCTAssertEqual(
            PriorExerciseLookup.dateLabel(day: prior!.day, now: now, calendar: calendar),
            "Yesterday"
        )
        XCTAssertEqual(
            PriorExerciseLookup.dateLabel(day: now, now: now, calendar: calendar),
            "Today"
        )
        let november12 = date(year: 2026, month: 11, day: 12)
        let olderLabel = PriorExerciseLookup.dateLabel(day: november12, now: now, calendar: calendar)
        XCTAssertFalse(olderLabel == "Today" || olderLabel == "Yesterday")
        XCTAssertTrue(olderLabel.contains("12"))
        XCTAssertNil(
            PriorExerciseLookup.latest(kind: .legExtensionHeavy, in: [older, newer], calendar: calendar)
        )
        let aggregate = PriorExerciseLookup.latest(
            kind: .isometricLegExtension,
            in: [older],
            calendar: calendar
        )
        XCTAssertEqual(aggregate?.lines, ["2 × 40s @ 50 lb"])
        XCTAssertEqual(aggregate?.sets.map(\.holdSeconds), [40, 40])
        XCTAssertEqual(aggregate?.sets.map(\.loadLbs), [50, 50])
    }

    func testStepLineStaysQuietUntilAskedAndWhenUnavailable() {
        XCTAssertEqual(TodayStepsCopy.label(.notAsked), "Steps from Apple Health")
        XCTAssertEqual(TodayStepsCopy.label(.unavailable), "Steps unavailable")
        let count = TodayStepsCopy.label(.count(4821))
        XCTAssertTrue(count.hasSuffix("steps today"))
        XCTAssertTrue(count.contains("4821") || count.contains("4,821"))
        XCTAssertEqual(TodayStepsCopy.label(.count(0)), "0 steps today")
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

    private func date(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func session(
        day: Int = 0,
        on explicitDate: Date? = nil,
        type: SessionType,
        what: String,
        sets: [ResistanceSet],
        isDraft: Bool = false,
        createdAtOffset: TimeInterval = 0
    ) -> TrainingSessionSnapshot {
        let date = explicitDate
            ?? calendar.date(byAdding: .day, value: day, to: Date(timeIntervalSince1970: 1_700_000_000))!
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
