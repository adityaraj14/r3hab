import Foundation

/// Adi's 12-week patellar tendinopathy plan.
///
/// Three training days a week (Monday, Wednesday, Friday) for weeks 1–10.
/// Weeks 11–12 keep two heavy days (Monday and Friday) and use Wednesday
/// for springiness. The other days are a walk or a stretch. The seated
/// leg extension hold is available every day. Nothing in the plan loads the back.
enum PlanExerciseKind: String, Equatable, Sendable, CaseIterable {
    case isometricLegExtension
    case singleLegPress
    case hipAbduction
    case calfRaise
    case legExtension
    case legPress
    case spanishSquat
    case pogoHop
    case boxJumpUp
    case landing
}

enum PlanDayKind: String, Equatable, Sendable {
    case training
    case heavy
    case plyometric
    case recovery

    var title: String {
        switch self {
        case .training: return "Training day"
        case .heavy: return "Heavy day"
        case .plyometric: return "Springiness day"
        case .recovery: return "Walk or stretch"
        }
    }

    var isSessionDay: Bool { self != .recovery }
}

enum PlyoStage: Int, Equatable, Sendable, Comparable {
    case pogo = 0
    case boxJump = 1
    case landing = 2

    static func < (lhs: PlyoStage, rhs: PlyoStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var kinds: [PlanExerciseKind] {
        switch self {
        case .pogo: return [.pogoHop]
        case .boxJump: return [.pogoHop, .boxJumpUp]
        case .landing: return [.pogoHop, .boxJumpUp, .landing]
        }
    }
}

struct PlanExercise: Equatable, Sendable, Identifiable {
    var id: PlanExerciseKind
    var name: String
    var sets: Int
    var reps: Int
    var holdSeconds: Int?
    var restSeconds: Int
    var tempo: String?
    var effort: String
    var note: String?
    var optional: Bool
    var logsWeight: Bool
    var sessionType: SessionType
    var presetID: String
    var isWarmup: Bool

    var doseLine: String {
        let work: String
        if let holdSeconds {
            work = "\(sets) holds of \(holdSeconds) seconds"
        } else {
            work = "\(sets)×\(reps)"
        }
        var parts = [work, Self.restLabel(restSeconds)]
        if let tempo { parts.append(tempo) }
        return parts.joined(separator: " · ")
    }

    private static func restLabel(_ seconds: Int) -> String {
        if seconds % 60 == 0 {
            let minutes = seconds / 60
            return "rest \(minutes) \(minutes == 1 ? "minute" : "minutes")"
        }
        return "rest \(seconds) seconds"
    }
}

struct DayPlan: Equatable, Sendable {
    var programWeek: Int
    /// Week used for doses. Stays on 12 after the plan ends.
    var week: Int
    var phase: RehabPhase
    var kind: PlanDayKind
    var exercises: [PlanExercise]
    var dailyIsometric: PlanExercise
    var summary: String
    /// Set when springiness is repeating a drill instead of adding the next one.
    var plyoNote: String?

    var weekLabel: String {
        if programWeek > TwelveWeekPlan.weekCount {
            return "Week \(programWeek) · repeat week \(TwelveWeekPlan.weekCount)"
        }
        return "Week \(week) of \(TwelveWeekPlan.weekCount)"
    }
}

struct MorningResponse: Equatable, Sendable {
    var baseline: Int?
    var nextMorning: Int?
    var aboveBaseline: Bool
    var missingNextMorning: Bool
}

struct LoadAdvice: Equatable, Sendable {
    var target: LoadPrescription
    var last: LoadPrescription?
    var stance: ProgressionStance
    var reason: String
    var painWarning: String?
    var blockedBy: [ProgressionGate]
    var pendingResolveID: UUID?
    var lastLoggedReps: Int?
    var laterality: SetLaterality
}

struct DeclineSquatTrend: Equatable, Sendable {
    enum Direction: String, Equatable, Sendable {
        case down
        case flat
        case up
        case notEnough
    }

    struct Point: Equatable, Sendable {
        var week: Int
        var score: Int
    }

    var points: [Point]
    var direction: Direction
    var headline: String
    var needsTest: Bool
}

enum PainRule {
    static let duringLimit = 3

    static func exceedsLimit(_ pain: Int) -> Bool {
        pain > duringLimit
    }

    static func warning(for pain: Int) -> String? {
        guard exceedsLimit(pain) else { return nil }
        return "Pain during is \(pain). Up to 3 out of 10 is the limit during the exercise."
    }
}

enum TwelveWeekPlan {
    static let weekCount = 12
    static let loadIncrementLbs = 5.0
    static let protocolRevision = "12-week · 2026-11-11"
    static let spanishSquatSkipNote = "Optional. Skip if it bothers your back."
    static let holdOffRunningAndJumping = "Hold off on high-volume jumping and running until week 11."
    /// Monday, Wednesday, Friday. Gregorian weekday: Sunday is 1.
    static let trainingWeekdays: Set<Int> = [2, 4, 6]
    static let heavyWeekdays: Set<Int> = [2, 6]
    static let plyoWeekday = 4

    static let reasonPickLoad = "Pick a load you can do with pain at or under 3."
    static let reasonLightStart = "Start light, in a pain-free range. Do not add weight yet."
    static let reasonHold = "Keep this load."
    static let reasonWeeklyIncrease = "New week, and the next morning stayed at baseline. Add weight."
    static let reasonDropOneSession = "The next morning was above baseline. Drop the load for this one session."
    static let reasonAwaitMorning = "The next morning is not recorded. Keep this load until it is."
    static let reasonPainHeld = "Pain during was over 3. The next morning was at baseline, so keep this load."
    static let reasonRestored = "The lighter session is done. Return to the previous load."
    static let reasonOutsidePlan = "This exercise is not in the 12-week knee plan."

    // MARK: Calendar

    static func isUnsetStart(_ date: Date) -> Bool {
        date.timeIntervalSince1970 < 86_400 * 365
    }

    /// First program week for a stored phase. Legacy A and B open week 1.
    /// Legacy C opens week 3 so an in-progress heavy block is not rewound to isometrics.
    static func openingWeek(for phase: RehabPhase) -> Int {
        switch RehabPhase.planPhase(for: phase) {
        case .calmTendon: return 1
        case .heavySlow: return 3
        case .heavier: return 7
        case .springiness: return 11
        default: return 1
        }
    }

    static func startDate(
        landingTodayInWeek week: Int,
        today: Date,
        calendar: Calendar = .current
    ) -> Date {
        let clamped = min(max(week, 1), weekCount)
        let day = calendar.startOfDay(for: today)
        return calendar.date(byAdding: .day, value: -(clamped - 1) * 7, to: day) ?? day
    }

    static func programWeek(start: Date, on date: Date, calendar: Calendar) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let day = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startDay, to: day).day ?? 0
        if days < 0 { return 1 }
        return days / 7 + 1
    }

    static func contentWeek(_ programWeek: Int) -> Int {
        min(max(programWeek, 1), weekCount)
    }

    static func phase(forWeek week: Int) -> RehabPhase {
        switch contentWeek(week) {
        case 1...2: return .calmTendon
        case 3...6: return .heavySlow
        case 7...10: return .heavier
        default: return .springiness
        }
    }

    static func phase(on date: Date, start: Date, calendar: Calendar = .current) -> RehabPhase {
        phase(forWeek: programWeek(start: start, on: date, calendar: calendar))
    }

    /// Heavy-slow rep scheme. Weeks 3–6 step 15 → 10. Weeks 7–12 step 8 → 6.
    static func heavyReps(forWeek week: Int) -> Int {
        switch contentWeek(week) {
        case 3: return 15
        case 4: return 13
        case 5: return 12
        case 6: return 10
        case 7: return 8
        case 8: return 7
        case 9: return 7
        case 10: return 6
        case 11, 12: return 6
        default: return 15
        }
    }

    static func dayKind(week: Int, weekday: Int) -> PlanDayKind {
        let content = contentWeek(week)
        if content >= 11 {
            if heavyWeekdays.contains(weekday) { return .heavy }
            if weekday == plyoWeekday { return .plyometric }
            return .recovery
        }
        if trainingWeekdays.contains(weekday) { return .training }
        return .recovery
    }

    // MARK: Session content

    static func dayPlan(
        start: Date,
        on date: Date,
        calendar: Calendar = .current,
        plyoStage: PlyoStage = .pogo,
        plyoNote: String? = nil
    ) -> DayPlan {
        let program = programWeek(start: start, on: date, calendar: calendar)
        let week = contentWeek(program)
        let phase = phase(forWeek: week)
        let weekday = calendar.component(.weekday, from: date)
        let kind = dayKind(week: week, weekday: weekday)
        let iso = exercise(.isometricLegExtension, week: week, isWarmup: kind != .recovery && week >= 3)
        let exercises = sessionExercises(kind: kind, week: week, plyoStage: plyoStage)
        var summary = summaryLine(kind: kind, phase: phase)
        if program > weekCount {
            summary += " Week 12 is the last programmed week. Repeat it until you change the plan."
        }
        return DayPlan(
            programWeek: program,
            week: week,
            phase: phase,
            kind: kind,
            exercises: exercises,
            dailyIsometric: iso,
            summary: summary,
            plyoNote: kind == .plyometric ? plyoNote : nil
        )
    }

    static func dayPlan(
        start: Date,
        on date: Date,
        sessions: [TrainingSessionSnapshot],
        checkIns: [DailyCheckInSnapshot],
        calendar: Calendar = .current
    ) -> DayPlan {
        let gate = plyoGate(sessions: sessions, checkIns: checkIns, asOf: date, calendar: calendar)
        return dayPlan(
            start: start,
            on: date,
            calendar: calendar,
            plyoStage: gate.stage,
            plyoNote: gate.note
        )
    }

    static func prescribesRunningOrHighVolumeJumping(_ plan: DayPlan) -> Bool {
        if plan.week < 11 {
            let plyo: Set<PlanExerciseKind> = [.pogoHop, .boxJumpUp, .landing]
            if plan.exercises.contains(where: { plyo.contains($0.id) }) { return true }
        }
        return plan.exercises.contains { exercise in
            let name = exercise.name.lowercased()
            return name.contains("run") || name.contains("jog")
        }
    }

    static func exercise(_ kind: PlanExerciseKind, week: Int, isWarmup: Bool = false) -> PlanExercise {
        let content = contentWeek(week)
        switch kind {
        case .isometricLegExtension:
            return PlanExercise(
                id: kind,
                name: "Seated leg extension hold",
                sets: 5,
                reps: 5,
                holdSeconds: 45,
                restSeconds: 120,
                tempo: nil,
                effort: "Hard, but the pain stays tolerable.",
                note: isWarmup
                    ? "Warm-up. Seated, so your back stays unloaded. You can also do this on its own, any day."
                    : "You can do this every day, including before other activity. Seated, so your back stays unloaded.",
                optional: false,
                logsWeight: true,
                sessionType: .isometrics,
                presetID: "ext",
                isWarmup: isWarmup
            )
        case .singleLegPress:
            return PlanExercise(
                id: kind,
                name: "Single-leg leg press",
                sets: 3,
                reps: 15,
                holdSeconds: nil,
                restSeconds: 90,
                tempo: "Slow",
                effort: "Light. Stay in a pain-free range.",
                note: "One leg at a time. Stay seated so your back stays unloaded.",
                optional: false,
                logsWeight: true,
                sessionType: .hsrStrength,
                presetID: "slp",
                isWarmup: false
            )
        case .hipAbduction:
            return PlanExercise(
                id: kind,
                name: "Side-lying hip abduction",
                sets: 3,
                reps: 15,
                holdSeconds: nil,
                restSeconds: 60,
                tempo: nil,
                effort: "Body weight.",
                note: "Side-lying. This does not load your back.",
                optional: false,
                logsWeight: false,
                sessionType: .other,
                presetID: "hip",
                isWarmup: false
            )
        case .calfRaise:
            return PlanExercise(
                id: kind,
                name: "Calf raise",
                sets: 3,
                reps: 15,
                holdSeconds: nil,
                restSeconds: 60,
                tempo: nil,
                effort: "Body weight.",
                note: "Body weight. Do not hold a weight on your shoulders.",
                optional: false,
                logsWeight: false,
                sessionType: .other,
                presetID: "calf",
                isWarmup: false
            )
        case .legExtension:
            return heavyLift(
                kind: kind,
                name: "Seated leg extension",
                week: content,
                note: "Seated, so your back stays unloaded.",
                presetID: "ke"
            )
        case .legPress:
            return heavyLift(
                kind: kind,
                name: "Leg press",
                week: content,
                note: "Use the machine so your back stays supported.",
                presetID: "lp"
            )
        case .spanishSquat:
            return PlanExercise(
                id: kind,
                name: "Spanish squat",
                sets: 5,
                reps: 5,
                holdSeconds: 45,
                restSeconds: 120,
                tempo: nil,
                effort: "A deep squat with a band behind the knees.",
                note: spanishSquatSkipNote,
                optional: true,
                logsWeight: false,
                sessionType: .isometrics,
                presetID: "spanish",
                isWarmup: false
            )
        case .pogoHop:
            return PlanExercise(
                id: kind,
                name: "Pogo hop",
                sets: 3,
                reps: 20,
                holdSeconds: nil,
                restSeconds: 90,
                tempo: nil,
                effort: "Small, quiet hops.",
                note: "Progress only when the next morning does not flare.",
                optional: false,
                logsWeight: false,
                sessionType: .energyStorage,
                presetID: "pogo",
                isWarmup: false
            )
        case .boxJumpUp:
            return PlanExercise(
                id: kind,
                name: "Box jump-up",
                sets: 3,
                reps: 8,
                holdSeconds: nil,
                restSeconds: 90,
                tempo: nil,
                effort: "Jump up. Step down.",
                note: "This is not high-volume jumping.",
                optional: false,
                logsWeight: false,
                sessionType: .energyStorage,
                presetID: "box",
                isWarmup: false
            )
        case .landing:
            return PlanExercise(
                id: kind,
                name: "Landing",
                sets: 3,
                reps: 5,
                holdSeconds: nil,
                restSeconds: 90,
                tempo: nil,
                effort: "Controlled landings.",
                note: "Low volume. This is not a running session.",
                optional: false,
                logsWeight: false,
                sessionType: .energyStorage,
                presetID: "land",
                isWarmup: false
            )
        }
    }

    static func kind(presetID: String) -> PlanExerciseKind? {
        switch presetID {
        case "ext": return .isometricLegExtension
        case "slp", "lp-iso": return .singleLegPress
        case "hip": return .hipAbduction
        case "calf": return .calfRaise
        case "ke": return .legExtension
        case "lp": return .legPress
        case "spanish": return .spanishSquat
        case "pogo": return .pogoHop
        case "box": return .boxJumpUp
        case "land": return .landing
        default: return nil
        }
    }

    static func presetIDs(for phase: RehabPhase) -> [String] {
        switch RehabPhase.planPhase(for: phase) {
        case .calmTendon:
            return ["ext", "slp", "hip", "calf"]
        case .heavySlow:
            return ["ext", "ke", "lp"]
        case .heavier:
            return ["ext", "ke", "lp", "spanish"]
        case .springiness:
            return ["ext", "ke", "lp", "pogo", "box", "land"]
        default:
            return ["ext", "ke", "lp"]
        }
    }

    static func increasesWeightEachWeek(_ kind: PlanExerciseKind, week: Int) -> Bool {
        switch kind {
        case .legExtension, .legPress:
            return (3...12).contains(contentWeek(week))
        case .isometricLegExtension, .singleLegPress, .hipAbduction, .calfRaise,
             .spanishSquat, .pogoHop, .boxJumpUp, .landing:
            return false
        }
    }

    // MARK: Next morning and load

    static func morningResponse(
        sessionDay: Date,
        checkIns: [DailyCheckInSnapshot],
        calendar: Calendar
    ) -> MorningResponse {
        let day = calendar.startOfDay(for: sessionDay)
        let baseline = morningPain(on: day, checkIns: checkIns, calendar: calendar)
            ?? previousMorning(before: day, checkIns: checkIns, calendar: calendar)
        let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        let nextMorning = morningPain(on: next, checkIns: checkIns, calendar: calendar)
        let above: Bool
        if let baseline, let nextMorning {
            above = nextMorning > baseline
        } else {
            above = false
        }
        return MorningResponse(
            baseline: baseline,
            nextMorning: nextMorning,
            aboveBaseline: above,
            missingNextMorning: nextMorning == nil
        )
    }

    static func advise(
        kind: PlanExerciseKind,
        programStart: Date,
        sessions: [TrainingSessionSnapshot],
        checkIns: [DailyCheckInSnapshot],
        asOf: Date,
        calendar: Calendar
    ) -> LoadAdvice {
        let week = programWeek(start: programStart, on: asOf, calendar: calendar)
        let template = exercise(kind, week: week, isWarmup: false)
        let seeded = prescription(template, loadLbs: nil)
        guard template.logsWeight else {
            return LoadAdvice(
                target: seeded,
                last: nil,
                stance: .hold,
                reason: template.effort,
                painWarning: nil,
                blockedBy: [],
                pendingResolveID: nil,
                lastLoggedReps: nil,
                laterality: .bilateral
            )
        }
        let history = counted(sessions, kind: kind, onOrBefore: asOf, calendar: calendar)
        let laterality: SetLaterality = kind == .singleLegPress
            ? .unilateral
            : (history.last.map { SessionSummary.inferredLaterality(workSets: $0.resistanceSets) } ?? .bilateral)
        guard let latest = history.last else {
            let reason = kind == .singleLegPress ? reasonLightStart : reasonPickLoad
            return LoadAdvice(
                target: seeded,
                last: seeded,
                stance: .hold,
                reason: reason,
                painWarning: nil,
                blockedBy: [],
                pendingResolveID: nil,
                lastLoggedReps: nil,
                laterality: laterality
            )
        }

        let logged = ProgressionEngine.inferPrescription(latest)
            ?? LoadPrescription(workingSets: template.sets, reps: template.reps, loadLbs: nil)
        let morning = morningResponse(sessionDay: latest.date, checkIns: checkIns, calendar: calendar)
        let pain = ProgressionEngine.peakPain(in: latest)
        let warning = pain.flatMap(PainRule.warning(for:))
        let pendingID: UUID? = latest.response24h == .pending ? latest.id : nil
        let shortReps: Int? = template.holdSeconds == nil && logged.reps < template.reps ? logged.reps : nil
        var blocked: [ProgressionGate] = []
        if warning != nil { blocked.append(.painDuring) }
        if morning.missingNextMorning { blocked.append(.awaiting24h) }

        func advice(
            load: Double?,
            stance: ProgressionStance,
            reason: String,
            extra: [ProgressionGate] = []
        ) -> LoadAdvice {
            var target = prescription(template, loadLbs: load)
            if template.holdSeconds != nil {
                target.holdSeconds = template.holdSeconds
                target.restSeconds = template.restSeconds
            } else {
                target.restSeconds = template.restSeconds
                target.tempo = template.tempo
            }
            return LoadAdvice(
                target: target,
                last: logged,
                stance: stance,
                reason: reason,
                painWarning: warning,
                blockedBy: blocked + extra,
                pendingResolveID: pendingID,
                lastLoggedReps: shortReps,
                laterality: laterality
            )
        }

        if morning.aboveBaseline {
            let dropped = logged.loadLbs.map { max(0, $0 - loadIncrementLbs) }
            return advice(
                load: dropped,
                stance: .drop,
                reason: reasonDropOneSession,
                extra: [.responseWorse]
            )
        }
        if morning.missingNextMorning {
            return advice(load: logged.loadLbs, stance: .hold, reason: reasonAwaitMorning)
        }

        var working = logged.loadLbs
        var restored = false
        if history.count >= 2 {
            let previous = history[history.count - 2]
            let previousMorning = morningResponse(sessionDay: previous.date, checkIns: checkIns, calendar: calendar)
            let previousLoad = ProgressionEngine.inferPrescription(previous)?.loadLbs
            if previousMorning.aboveBaseline,
               let previousLoad,
               let latestLoad = logged.loadLbs,
               latestLoad + 0.001 < previousLoad {
                working = previousLoad
                restored = true
            }
        }

        let painAllowsIncrease = pain != nil && (pain ?? 0) <= PainRule.duringLimit
        let laterWeek = programWeek(start: programStart, on: asOf, calendar: calendar)
            > programWeek(start: programStart, on: latest.date, calendar: calendar)
        if increasesWeightEachWeek(kind, week: week),
           laterWeek,
           painAllowsIncrease,
           let working {
            return advice(
                load: working + loadIncrementLbs,
                stance: .advance,
                reason: reasonWeeklyIncrease
            )
        }
        if warning != nil {
            return advice(load: working, stance: .hold, reason: reasonPainHeld)
        }
        if restored {
            return advice(load: working, stance: .hold, reason: reasonRestored)
        }
        if kind == .singleLegPress {
            return advice(load: working, stance: .hold, reason: reasonLightStart)
        }
        return advice(load: working, stance: .hold, reason: reasonHold)
    }

    // MARK: Plyometrics

    struct PlyoGate: Equatable, Sendable {
        var stage: PlyoStage
        var note: String?
    }

    static func plyoGate(
        sessions: [TrainingSessionSnapshot],
        checkIns: [DailyCheckInSnapshot],
        asOf: Date,
        calendar: Calendar
    ) -> PlyoGate {
        let day = calendar.startOfDay(for: asOf)
        let prior = sessions
            .filter { $0.isFinalized && $0.decision != .rest }
            .filter { calendar.startOfDay(for: $0.date) < day }
            .filter { plyoStage(in: $0.whatIDid) != nil }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.createdAt < rhs.createdAt
            }
        guard let latest = prior.last, let stage = plyoStage(in: latest.whatIDid) else {
            return PlyoGate(stage: .pogo, note: nil)
        }
        let morning = morningResponse(sessionDay: latest.date, checkIns: checkIns, calendar: calendar)
        if morning.aboveBaseline {
            return PlyoGate(
                stage: stage,
                note: "The next morning flared. Repeat this. Do not add the next drill."
            )
        }
        if morning.missingNextMorning {
            return PlyoGate(
                stage: stage,
                note: "Log the next morning before you add the next drill."
            )
        }
        if let pain = ProgressionEngine.peakPain(in: latest), PainRule.exceedsLimit(pain) {
            return PlyoGate(
                stage: stage,
                note: "Pain during was over 3. Repeat this drill."
            )
        }
        let next = PlyoStage(rawValue: min(stage.rawValue + 1, PlyoStage.landing.rawValue)) ?? .landing
        return PlyoGate(stage: next, note: nil)
    }

    static func plyoStage(in text: String) -> PlyoStage? {
        let lowered = text.lowercased()
        if lowered.contains("landing") { return .landing }
        if lowered.contains("box jump") { return .boxJump }
        if lowered.contains("pogo") { return .pogo }
        return nil
    }

    // MARK: Decline squat

    static func declineTrend(
        start: Date,
        checkIns: [DailyCheckInSnapshot],
        asOf: Date,
        calendar: Calendar
    ) -> DeclineSquatTrend {
        let current = programWeek(start: start, on: asOf, calendar: calendar)
        var latestByWeek: [Int: (date: Date, score: Int)] = [:]
        for row in checkIns {
            guard let score = declineScore(row) else { continue }
            let week = programWeek(start: start, on: row.date, calendar: calendar)
            if let existing = latestByWeek[week], existing.date > row.date { continue }
            latestByWeek[week] = (row.date, score)
        }
        let points = latestByWeek.keys.sorted().map {
            DeclineSquatTrend.Point(week: $0, score: latestByWeek[$0]?.score ?? 0)
        }
        let direction: DeclineSquatTrend.Direction
        let headline: String
        if points.count < 2 {
            direction = .notEnough
            headline = "Log the single-leg decline squat once each week. The aim is a downward trend."
        } else {
            let previous = points[points.count - 2].score
            let last = points[points.count - 1].score
            if last < previous {
                direction = .down
                headline = "The decline squat pain is going down."
            } else if last > previous {
                direction = .up
                headline = "The decline squat pain went up."
            } else {
                direction = .flat
                headline = "The decline squat pain is unchanged."
            }
        }
        return DeclineSquatTrend(
            points: points,
            direction: direction,
            headline: headline,
            needsTest: latestByWeek[current] == nil
        )
    }

    static func declineScore(_ row: DailyCheckInSnapshot) -> Int? {
        let scores = [row.declineSquatL, row.declineSquatR].compactMap { $0 }
        return scores.max()
    }

    // MARK: Private

    private static func sessionExercises(
        kind: PlanDayKind,
        week: Int,
        plyoStage: PlyoStage
    ) -> [PlanExercise] {
        switch kind {
        case .recovery:
            return []
        case .training, .heavy:
            if week <= 2 {
                return [
                    exercise(.isometricLegExtension, week: week),
                    exercise(.singleLegPress, week: week),
                    exercise(.hipAbduction, week: week),
                    exercise(.calfRaise, week: week)
                ]
            }
            var rows = [
                exercise(.isometricLegExtension, week: week, isWarmup: true),
                exercise(.legExtension, week: week),
                exercise(.legPress, week: week)
            ]
            if (7...10).contains(week) {
                rows.append(exercise(.spanishSquat, week: week))
            }
            return rows
        case .plyometric:
            return plyoStage.kinds.map { exercise($0, week: week) }
        }
    }

    private static func heavyLift(
        kind: PlanExerciseKind,
        name: String,
        week: Int,
        note: String,
        presetID: String
    ) -> PlanExercise {
        PlanExercise(
            id: kind,
            name: name,
            sets: 4,
            reps: heavyReps(forWeek: week),
            holdSeconds: nil,
            restSeconds: 120,
            tempo: "3 seconds up, 3 seconds down",
            effort: "Slow and heavy. Add weight this week only if the next morning stayed at baseline.",
            note: note,
            optional: false,
            logsWeight: true,
            sessionType: .hsrStrength,
            presetID: presetID,
            isWarmup: false
        )
    }

    private static func summaryLine(kind: PlanDayKind, phase: RehabPhase) -> String {
        switch kind {
        case .recovery:
            return "Walk or stretch. The seated leg extension hold is available today."
        case .plyometric:
            return "Bring back springiness. Progress only when the next morning does not flare."
        case .training, .heavy:
            switch phase {
            case .calmTendon:
                return "Calm the tendon. Pain up to 3 out of 10 is fine if it is back to baseline by the next morning."
            case .heavySlow, .heavier, .cHeavySlowResistance:
                return "Heavy slow resistance. 3 seconds up and 3 seconds down."
            case .springiness:
                return "Heavy day. Keep the load slow. Two heavy days this week."
            case .aFlareDeLoad, .bIsometrics:
                return "Calm the tendon."
            }
        }
    }

    private static func prescription(_ exercise: PlanExercise, loadLbs: Double?) -> LoadPrescription {
        LoadPrescription(
            workingSets: exercise.sets,
            reps: exercise.holdSeconds == nil ? exercise.reps : 1,
            loadLbs: loadLbs,
            holdSeconds: exercise.holdSeconds,
            restSeconds: exercise.restSeconds,
            tempo: exercise.tempo
        )
    }

    private static func counted(
        _ sessions: [TrainingSessionSnapshot],
        kind: PlanExerciseKind,
        onOrBefore asOf: Date,
        calendar: Calendar
    ) -> [TrainingSessionSnapshot] {
        let day = calendar.startOfDay(for: asOf)
        return sessions
            .filter { session in
                session.isFinalized
                    && session.decision != .rest
                    && session.response24h != .notApplicable
                    && calendar.startOfDay(for: session.date) <= day
                    && matches(session, kind: kind)
                    && !SessionSummary.groupWorkSets(session.resistanceSets.filter { !$0.isWarmup }).isEmpty
            }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.createdAt < rhs.createdAt
            }
    }

    static func matches(_ session: TrainingSessionSnapshot, kind: PlanExerciseKind) -> Bool {
        let text = session.whatIDid.lowercased()
        switch kind {
        case .isometricLegExtension:
            let named = text.contains("seated leg extension") || text.contains("seated extension")
            return named && (session.sessionType == .isometrics || text.contains("hold"))
        case .legExtension:
            let named = text.contains("seated leg extension") || text.contains("seated extension")
            return named && session.sessionType == .hsrStrength && !text.contains("hold")
        case .singleLegPress:
            return text.contains("single-leg") && text.contains("leg press")
        case .legPress:
            return text.contains("leg press") && !text.contains("single-leg")
        case .hipAbduction:
            return text.contains("hip abduction")
        case .calfRaise:
            return text.contains("calf raise")
        case .spanishSquat:
            return text.contains("spanish squat")
        case .pogoHop:
            return text.contains("pogo")
        case .boxJumpUp:
            return text.contains("box jump")
        case .landing:
            return text.contains("landing") && !text.contains("box jump")
        }
    }

    private static func morningPain(
        on day: Date,
        checkIns: [DailyCheckInSnapshot],
        calendar: Calendar
    ) -> Int? {
        checkIns.first { calendar.isDate($0.date, inSameDayAs: day) }?.restingPainAM
    }

    private static func previousMorning(
        before day: Date,
        checkIns: [DailyCheckInSnapshot],
        calendar: Calendar
    ) -> Int? {
        checkIns
            .filter { calendar.startOfDay(for: $0.date) < day && $0.restingPainAM != nil }
            .sorted { $0.date > $1.date }
            .first?
            .restingPainAM
    }
}
