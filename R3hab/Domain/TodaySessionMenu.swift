import Foundation

/// Compact Today row that opens the day's prescribed session.
struct TodaySessionLink: Equatable, Sendable {
    var title: String
    var exerciseCount: Int
    /// Count on a session day. Rest-day copy on a recovery day.
    var detail: String
    var status: TodaySessionMenuStatus
    var isRestDay: Bool
}

enum TodaySessionMenuStatus: Equatable, Sendable {
    case notDone
    case inProgress
    case done
    case rest

    var label: String {
        switch self {
        case .notDone: return "Not done"
        case .inProgress: return "In progress"
        case .done: return "Done"
        case .rest: return "Rest day"
        }
    }
}

/// Home shows one row. The prescribed list — dose, tempo, notes — lives on its page.
enum TodaySessionMenu {
    /// Exercises the session page lists. A recovery day still offers the daily hold.
    static func listedExercises(in plan: DayPlan) -> [PlanExercise] {
        if plan.exercises.contains(where: { $0.id == .isometricLegExtension }) {
            return plan.exercises
        }
        return [plan.dailyIsometric] + plan.exercises
    }

    static func link(
        plan: DayPlan,
        on date: Date,
        calendar: Calendar,
        todaySessions: [TrainingSessionSnapshot],
        hasDraft: Bool
    ) -> TodaySessionLink {
        let exercises = listedExercises(in: plan)
        let menuStatus = status(
            plan: plan,
            exercises: exercises,
            todaySessions: todaySessions,
            hasDraft: hasDraft
        )
        let weekday = PlanSchedule.weekdayName(date, calendar: calendar)
        let isRestDay = plan.kind == .recovery
        return TodaySessionLink(
            title: title(weekday: weekday, plan: plan),
            exerciseCount: exercises.count,
            detail: isRestDay ? plan.summary : exerciseCountLine(exercises.count),
            status: menuStatus,
            isRestDay: isRestDay
        )
    }

    static func title(weekday: String, plan: DayPlan) -> String {
        let week = "Week \(plan.week)"
        let head = weekday.isEmpty ? week : "\(weekday) — \(week)"
        guard plan.kind != .recovery else { return head }
        return "\(head) \(tag(for: plan))"
    }

    /// Short block name for the home row. Week 3 is HSR. A plyo day is Plyo.
    static func tag(for plan: DayPlan) -> String {
        switch plan.kind {
        case .recovery:
            return "Rest"
        case .plyometric:
            return "Plyo"
        case .training, .heavy:
            switch plan.phase {
            case .calmTendon, .aFlareDeLoad, .bIsometrics:
                return "Isometrics"
            case .heavySlow, .cHeavySlowResistance:
                return SessionType.hsrStrength.shortTag
            case .heavier:
                return "Heavier"
            case .springiness:
                return SessionType.hsrStrength.shortTag
            }
        }
    }

    static func exerciseCountLine(_ count: Int) -> String {
        count == 1 ? "1 exercise" : "\(count) exercises"
    }

    static func loggedKinds(
        exercises: [PlanExercise],
        sessions: [TrainingSessionSnapshot]
    ) -> Set<PlanExerciseKind> {
        Set(exercises.compactMap { exercise in
            let recorded = sessions.contains { session in
                session.isFinalized && TwelveWeekPlan.matches(session, kind: exercise.id)
            }
            return recorded ? exercise.id : nil
        })
    }

    /// Done when every required exercise has a finalized log today.
    /// A rest day with nothing logged stays a rest day. A draft is in progress.
    static func status(
        plan: DayPlan,
        exercises: [PlanExercise],
        todaySessions: [TrainingSessionSnapshot],
        hasDraft: Bool
    ) -> TodaySessionMenuStatus {
        let logged = loggedKinds(exercises: exercises, sessions: todaySessions)
        let required = exercises.filter { !$0.optional }
        let requiredDone = !required.isEmpty && required.allSatisfy { logged.contains($0.id) }
        if requiredDone { return .done }
        if plan.kind == .recovery && logged.isEmpty && !hasDraft { return .rest }
        if hasDraft || !logged.isEmpty { return .inProgress }
        return .notDone
    }
}
