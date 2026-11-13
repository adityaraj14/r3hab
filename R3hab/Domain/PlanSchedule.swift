import Foundation

/// A planned training day done on a different calendar day.
///
/// The program week and phase stay on the program clock. This record says
/// which planned session was fulfilled, and on which day the work happened,
/// so the next session can keep two days between heavy sessions.
struct PlanSessionOverride: Equatable, Sendable, Identifiable, Codable {
    var id: UUID
    /// The Monday, Wednesday, or Friday the plan scheduled.
    var scheduledDate: Date
    /// The day the session was actually done. May be a rest day.
    var performedDate: Date
    /// Logged session that fulfills the planned day, once one is saved.
    var sessionID: UUID?

    init(id: UUID = UUID(), scheduledDate: Date, performedDate: Date, sessionID: UUID? = nil) {
        self.id = id
        self.scheduledDate = scheduledDate
        self.performedDate = performedDate
        self.sessionID = sessionID
    }
}

enum PlanOverrideStore {
    static func decode(_ json: String) -> [PlanSessionOverride] {
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([PlanSessionOverride].self, from: data) else {
            return []
        }
        return decoded
    }

    static func encode(_ overrides: [PlanSessionOverride]) -> String {
        guard let data = try? JSONEncoder().encode(overrides),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    /// Inserts or replaces the override for the same planned day, and drops
    /// any other override that already uses the performed day.
    static func upsert(
        _ item: PlanSessionOverride,
        into list: [PlanSessionOverride]
    ) -> [PlanSessionOverride] {
        let next = list.filter {
            $0.id != item.id
                && $0.scheduledDate != item.scheduledDate
                && $0.performedDate != item.performedDate
        }
        return (next + [item]).sorted { $0.scheduledDate < $1.scheduledDate }
    }

    static func removing(id: UUID, from list: [PlanSessionOverride]) -> [PlanSessionOverride] {
        list.filter { $0.id != id }
    }
}

/// One planned session after overrides and real logs have been applied.
struct PlannedSession: Equatable, Sendable, Identifiable {
    var scheduledDate: Date
    var placedDate: Date
    var week: Int
    var phase: RehabPhase
    var kind: PlanDayKind
    var fulfilled: Bool

    var id: Date { scheduledDate }
}

struct PlanScheduleSnapshot: Equatable, Sendable {
    var programWeek: Int
    var phase: RehabPhase
    var kind: PlanDayKind
    /// Day whose exercises apply. The calendar day for an ordinary day.
    var prescriptionDate: Date
    /// Planned day this calendar day is carrying, when the session was moved.
    var fulfillsScheduledDate: Date?
    /// Next heavy session strictly after today.
    var nextSessionDate: Date?
    var missedSlotDates: [Date]
    /// Fulfilled planned sessions whose scheduled day falls in today's program week.
    var fulfilledThisWeek: Int
    /// Today is a calendar training day pushed later to keep two days' rest.
    var deferredBySpacing: Bool

    func restLine(calendar: Calendar) -> String {
        guard let next = nextSessionDate else {
            return "The seated hold is optional today."
        }
        let name = PlanSchedule.weekdayName(next, calendar: calendar)
        if deferredBySpacing {
            return "Keep two days between heavy sessions. Next training day is \(name)."
        }
        return "The seated hold is optional today. Next training day is \(name)."
    }
}

/// Where each planned session lands once make-ups and real logs are counted.
///
/// Week and phase stay on the program clock (`programStart`). A make-up
/// fulfills its planned day, so that day is not missed. The next unfulfilled
/// session is placed at least `SessionSpacing.hardCadenceDays` after the last
/// heavy day (about 48 hours).
enum PlanSchedule {
    static func weekdayName(_ date: Date, calendar: Calendar) -> String {
        let index = calendar.component(.weekday, from: date) - 1
        guard calendar.weekdaySymbols.indices.contains(index) else { return "" }
        return calendar.weekdaySymbols[index]
    }

    static func slotLabel(_ slot: PlannedSession, calendar: Calendar) -> String {
        let name = weekdayName(slot.scheduledDate, calendar: calendar)
        let day = slot.scheduledDate.formatted(date: .abbreviated, time: .omitted)
        return "\(name) · \(day)"
    }

    static func makeUpLine(scheduled: Date, calendar: Calendar) -> String {
        let name = weekdayName(scheduled, calendar: calendar)
        return "Make-up for \(name)."
    }

    static func normalize(
        _ overrides: [PlanSessionOverride],
        calendar: Calendar
    ) -> [PlanSessionOverride] {
        var bySlot: [Date: PlanSessionOverride] = [:]
        for var item in overrides {
            item.scheduledDate = calendar.startOfDay(for: item.scheduledDate)
            item.performedDate = calendar.startOfDay(for: item.performedDate)
            if item.performedDate == item.scheduledDate { continue }
            bySlot[item.scheduledDate] = item
        }
        var seenPerformed: Set<Date> = []
        var result: [PlanSessionOverride] = []
        for item in bySlot.values.sorted(by: { $0.scheduledDate < $1.scheduledDate }) {
            if seenPerformed.contains(item.performedDate) { continue }
            seenPerformed.insert(item.performedDate)
            result.append(item)
        }
        return result
    }

    static func plannedSessions(
        start: Date,
        asOf: Date,
        sessions: [TrainingSessionSnapshot],
        overrides: [PlanSessionOverride],
        calendar: Calendar,
        horizonDays: Int = 21
    ) -> [PlannedSession] {
        let startDay = calendar.startOfDay(for: start)
        let today = calendar.startOfDay(for: asOf)
        let stored = normalize(overrides, calendar: calendar)
        let slotOverrides = stored.filter { isPlanSessionDay(start: startDay, on: $0.scheduledDate, calendar: calendar) }
        let overrideByScheduled = Dictionary(uniqueKeysWithValues: slotOverrides.map { ($0.scheduledDate, $0) })

        var hardCounts: [Date: Int] = [:]
        for session in sessions where isTrainingLog(session) {
            let day = calendar.startOfDay(for: session.date)
            hardCounts[day, default: 0] += 1
        }
        var anchors = Set(hardCounts.keys)
        for item in slotOverrides {
            anchors.insert(item.performedDate)
        }

        var end = calendar.date(byAdding: .day, value: horizonDays, to: today) ?? today
        for item in slotOverrides {
            if item.performedDate > end { end = item.performedDate }
            if item.scheduledDate > end { end = item.scheduledDate }
        }

        var slotDates: Set<Date> = []
        var raw: [(date: Date, week: Int, phase: RehabPhase, kind: PlanDayKind)] = []
        var day = startDay
        while day <= end {
            let week = TwelveWeekPlan.programWeek(start: startDay, on: day, calendar: calendar)
            let weekday = calendar.component(.weekday, from: day)
            let kind = TwelveWeekPlan.dayKind(week: week, weekday: weekday)
            if kind.isSessionDay {
                slotDates.insert(day)
                raw.append((day, week, TwelveWeekPlan.phase(forWeek: week), kind))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        return raw.map { slot in
            if let override = overrideByScheduled[slot.date] {
                return PlannedSession(
                    scheduledDate: slot.date,
                    placedDate: override.performedDate,
                    week: slot.week,
                    phase: slot.phase,
                    kind: slot.kind,
                    fulfilled: true
                )
            }
            let placed = place(
                scheduled: slot.date,
                anchors: anchors,
                slotDates: slotDates,
                claimsOnScheduled: claimCount(slot.date, overrides: slotOverrides),
                calendar: calendar
            )
            let fulfilled = fulfills(
                scheduled: slot.date,
                placed: placed,
                hardCounts: hardCounts,
                overrides: slotOverrides,
                slotDates: slotDates
            )
            return PlannedSession(
                scheduledDate: slot.date,
                placedDate: placed,
                week: slot.week,
                phase: slot.phase,
                kind: slot.kind,
                fulfilled: fulfilled
            )
        }
    }

    static func resolve(
        start: Date,
        on date: Date,
        sessions: [TrainingSessionSnapshot],
        overrides: [PlanSessionOverride],
        calendar: Calendar
    ) -> PlanScheduleSnapshot {
        let startDay = calendar.startOfDay(for: start)
        let today = calendar.startOfDay(for: date)
        let slots = plannedSessions(
            start: startDay,
            asOf: today,
            sessions: sessions,
            overrides: overrides,
            calendar: calendar
        )
        let program = TwelveWeekPlan.programWeek(start: startDay, on: today, calendar: calendar)
        let phase = TwelveWeekPlan.phase(forWeek: program)
        let stored = normalize(overrides, calendar: calendar)
        let makeup = stored.first { $0.performedDate == today && isPlanSessionDay(start: startDay, on: $0.scheduledDate, calendar: calendar) }
        let todaySlots = slots.filter { $0.placedDate == today }
        let own = slots.first { $0.scheduledDate == today }
        let carried = todaySlots.first { $0.scheduledDate == today } ?? todaySlots.first

        let kind: PlanDayKind
        let prescription: Date
        let fulfills: Date?
        if let makeup, let slot = slots.first(where: { $0.scheduledDate == makeup.scheduledDate }) {
            kind = slot.kind
            prescription = slot.scheduledDate
            fulfills = slot.scheduledDate
        } else if let carried {
            kind = carried.kind
            prescription = carried.scheduledDate
            fulfills = carried.scheduledDate == today ? nil : carried.scheduledDate
        } else {
            kind = .recovery
            prescription = today
            fulfills = nil
        }

        let missed = slots
            .filter { !$0.fulfilled && $0.placedDate < today }
            .map(\.scheduledDate)
        let next = slots
            .filter { !$0.fulfilled && $0.placedDate > today }
            .map(\.placedDate)
            .min()
        let fulfilledThisWeek = slots.filter {
            $0.fulfilled && TwelveWeekPlan.programWeek(start: startDay, on: $0.scheduledDate, calendar: calendar) == program
        }.count
        let nominal = TwelveWeekPlan.dayKind(
            week: program,
            weekday: calendar.component(.weekday, from: today)
        )
        let deferred = kind == .recovery
            && nominal.isSessionDay
            && own != nil
            && (own?.placedDate ?? today) > today
            && own?.fulfilled != true

        return PlanScheduleSnapshot(
            programWeek: program,
            phase: phase,
            kind: kind,
            prescriptionDate: prescription,
            fulfillsScheduledDate: fulfills,
            nextSessionDate: next,
            missedSlotDates: missed,
            fulfilledThisWeek: fulfilledThisWeek,
            deferredBySpacing: deferred
        )
    }

    static func dayPlan(
        start: Date,
        on date: Date,
        sessions: [TrainingSessionSnapshot],
        checkIns: [DailyCheckInSnapshot],
        overrides: [PlanSessionOverride],
        calendar: Calendar
    ) -> DayPlan {
        let snapshot = resolve(
            start: start,
            on: date,
            sessions: sessions,
            overrides: overrides,
            calendar: calendar
        )
        var plan = TwelveWeekPlan.dayPlan(
            start: start,
            on: snapshot.prescriptionDate,
            sessions: sessions,
            checkIns: checkIns,
            calendar: calendar
        )
        let program = snapshot.programWeek
        plan.programWeek = program
        plan.week = TwelveWeekPlan.contentWeek(program)
        plan.phase = snapshot.phase
        if snapshot.kind == .recovery {
            plan.kind = .recovery
            plan.exercises = []
            plan.plyoNote = nil
            if snapshot.deferredBySpacing {
                plan.summary = snapshot.restLine(calendar: calendar)
            }
        }
        plan.fulfillsScheduledDate = snapshot.fulfillsScheduledDate
        if let scheduled = snapshot.fulfillsScheduledDate,
           !calendar.isDate(scheduled, inSameDayAs: date) {
            plan.summary = makeUpLine(scheduled: scheduled, calendar: calendar) + " " + plan.summary
        }
        return plan
    }

    static func prescriptionDate(
        start: Date,
        on date: Date,
        sessions: [TrainingSessionSnapshot],
        overrides: [PlanSessionOverride],
        calendar: Calendar
    ) -> Date {
        resolve(
            start: start,
            on: date,
            sessions: sessions,
            overrides: overrides,
            calendar: calendar
        ).prescriptionDate
    }

    /// Program day a logged session belongs to. An override keeps a make-up
    /// in the week it was planned, so a new week does not add load early.
    static func planDate(
        for session: TrainingSessionSnapshot,
        overrides: [PlanSessionOverride],
        calendar: Calendar
    ) -> Date {
        let day = calendar.startOfDay(for: session.date)
        let stored = normalize(overrides, calendar: calendar)
        if let link = stored.first(where: { $0.sessionID == session.id }) {
            return link.scheduledDate
        }
        if let match = stored.first(where: { $0.performedDate == day }) {
            return match.scheduledDate
        }
        return day
    }

    /// First effective session day of the program week that contains `asOf`.
    static func declineDueDate(
        start: Date,
        asOf: Date,
        sessions: [TrainingSessionSnapshot],
        overrides: [PlanSessionOverride],
        calendar: Calendar
    ) -> Date? {
        let startDay = calendar.startOfDay(for: start)
        let week = TwelveWeekPlan.programWeek(start: startDay, on: asOf, calendar: calendar)
        let slots = plannedSessions(
            start: startDay,
            asOf: asOf,
            sessions: sessions,
            overrides: overrides,
            calendar: calendar
        )
        return slots
            .filter {
                TwelveWeekPlan.programWeek(start: startDay, on: $0.scheduledDate, calendar: calendar) == week
            }
            .map(\.placedDate)
            .min()
    }

    static func loggableSlots(
        start: Date,
        on date: Date,
        sessions: [TrainingSessionSnapshot],
        overrides: [PlanSessionOverride],
        calendar: Calendar
    ) -> [PlannedSession] {
        let today = calendar.startOfDay(for: date)
        return plannedSessions(
            start: start,
            asOf: today,
            sessions: sessions,
            overrides: overrides,
            calendar: calendar
        )
        .filter { !$0.fulfilled && $0.scheduledDate <= today }
    }

    static func lastAnchor(
        before date: Date,
        sessions: [TrainingSessionSnapshot],
        overrides: [PlanSessionOverride],
        calendar: Calendar
    ) -> Date? {
        let day = calendar.startOfDay(for: date)
        var anchors: [Date] = sessions.compactMap { session in
            guard isTrainingLog(session) else { return nil }
            let logged = calendar.startOfDay(for: session.date)
            return logged < day ? logged : nil
        }
        for item in normalize(overrides, calendar: calendar) where item.performedDate < day {
            anchors.append(item.performedDate)
        }
        return anchors.max()
    }

    // MARK: Private

    private static func isTrainingLog(_ session: TrainingSessionSnapshot) -> Bool {
        session.isFinalized
            && session.decision != .rest
            && SessionSpacing.isHard(session.sessionType)
    }

    private static func isPlanSessionDay(start: Date, on date: Date, calendar: Calendar) -> Bool {
        let week = TwelveWeekPlan.programWeek(start: start, on: date, calendar: calendar)
        let weekday = calendar.component(.weekday, from: date)
        return TwelveWeekPlan.dayKind(week: week, weekday: weekday).isSessionDay
    }

    private static func claimCount(_ day: Date, overrides: [PlanSessionOverride]) -> Int {
        overrides.filter { $0.performedDate == day }.count
    }

    private static func place(
        scheduled: Date,
        anchors: Set<Date>,
        slotDates: Set<Date>,
        claimsOnScheduled: Int,
        calendar: Calendar
    ) -> Date {
        let blocking = anchors.filter { anchor in
            if anchor < scheduled { return true }
            return anchor == scheduled && claimsOnScheduled > 0
        }.max()
        var placed = scheduled
        if let blocking {
            let earliest = calendar.date(
                byAdding: .day,
                value: SessionSpacing.hardCadenceDays,
                to: blocking
            ) ?? placed
            if placed < earliest { placed = earliest }
        }
        var steps = 0
        while placed != scheduled && slotDates.contains(placed) && steps < 14 {
            placed = calendar.date(byAdding: .day, value: 1, to: placed) ?? placed
            steps += 1
        }
        return placed
    }

    private static func fulfills(
        scheduled: Date,
        placed: Date,
        hardCounts: [Date: Int],
        overrides: [PlanSessionOverride],
        slotDates: Set<Date>
    ) -> Bool {
        let claims = claimCount(scheduled, overrides: overrides)
        if (hardCounts[scheduled] ?? 0) > claims { return true }
        if placed == scheduled { return false }
        if slotDates.contains(placed) { return false }
        let placedClaims = claimCount(placed, overrides: overrides)
        return (hardCounts[placed] ?? 0) > placedClaims
    }
}
