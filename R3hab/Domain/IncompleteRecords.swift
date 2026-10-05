import Foundation

/// One unfinished piece of an earlier day (not today).
enum IncompleteKind: Equatable, Sendable {
    case unfinishedDraft(sessionID: UUID)
    case missingMorningPain
    case missingEveningPain
    case due24hResponse(sessionID: UUID)
}

struct IncompleteItem: Equatable, Identifiable, Sendable {
    var day: Date
    var kind: IncompleteKind

    var id: String {
        let key = CalendarDay.dayKey(day)
        switch kind {
        case .unfinishedDraft(let id): return "\(key)-draft-\(id.uuidString)"
        case .missingMorningPain: return "\(key)-am"
        case .missingEveningPain: return "\(key)-pm"
        case .due24hResponse(let id): return "\(key)-24h-\(id.uuidString)"
        }
    }
}

/// Check-in fields the incomplete scan needs. Wider than DailyCheckInSnapshot.
struct IncompleteDayCheckIn: Equatable, Sendable {
    var date: Date
    var hasMorningPain: Bool
    var hasEveningPain: Bool
}

/// Pending items on earlier days in the last `lookbackDays` days.
enum IncompleteRecords {
    static let lookbackDays = 7

    /// STE copy for the Today card and the morning notification.
    enum Copy {
        static let cardTitle = "Complete the pending record"
        static let cardEyebrow = "Earlier day"
        static let discardDraft = "Discard draft"
        static let discardTitle = "Discard this draft?"
        static let discardMessage = "R3hab deletes this draft. You cannot restore it."
        static let notificationTitle = "Pending record"

        static func dayLabel(_ day: Date, now: Date, calendar: Calendar) -> String {
            let today = CalendarDay.startOfDay(now, calendar: calendar)
            let start = CalendarDay.startOfDay(day, calendar: calendar)
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
               calendar.isDate(start, inSameDayAs: yesterday) {
                return "Yesterday"
            }
            return start.formatted(date: .abbreviated, time: .omitted)
        }

        static func line(_ item: IncompleteItem, now: Date, calendar: Calendar) -> String {
            let when = dayLabel(item.day, now: now, calendar: calendar)
            switch item.kind {
            case .unfinishedDraft:
                return "\(when): unfinished draft"
            case .missingMorningPain:
                return "\(when): morning pain"
            case .missingEveningPain:
                return "\(when): evening pain"
            case .due24hResponse:
                return "\(when): 24-hour response"
            }
        }

        static func notificationBody(_ items: [IncompleteItem], now: Date, calendar: Calendar) -> String {
            let lines = items.prefix(3).map { line($0, now: now, calendar: calendar) }
            if items.count > 3 {
                return lines.joined(separator: ". ") + ". And \(items.count - 3) more."
            }
            return lines.joined(separator: ". ") + "."
        }
    }

    /// Earlier days only. Newest day first; within a day: 24h, draft, morning, evening.
    static func items(
        sessions: [TrainingSessionSnapshot],
        checkIns: [IncompleteDayCheckIn],
        now: Date,
        calendar: Calendar = .current
    ) -> [IncompleteItem] {
        let today = CalendarDay.startOfDay(now, calendar: calendar)
        guard let windowStart = calendar.date(byAdding: .day, value: -(lookbackDays), to: today) else {
            return []
        }

        var checkByKey: [String: IncompleteDayCheckIn] = [:]
        for row in checkIns {
            let key = CalendarDay.dayKey(row.date, calendar: calendar)
            checkByKey[key] = row
        }

        var sessionByDay: [String: [TrainingSessionSnapshot]] = [:]
        for session in sessions {
            let start = CalendarDay.startOfDay(session.date, calendar: calendar)
            guard start < today, start >= windowStart else { continue }
            let key = CalendarDay.dayKey(start, calendar: calendar)
            sessionByDay[key, default: []].append(session)
        }

        var dayKeys = Set(sessionByDay.keys)
        for (key, row) in checkByKey {
            let start = CalendarDay.startOfDay(row.date, calendar: calendar)
            guard start < today, start >= windowStart else { continue }
            dayKeys.insert(key)
        }

        var result: [IncompleteItem] = []
        let orderedKeys = dayKeys.sorted(by: >)
        for key in orderedKeys {
            let daySessions = sessionByDay[key] ?? []
            let day = daySessions.first.map { CalendarDay.startOfDay($0.date, calendar: calendar) }
                ?? checkByKey[key].map { CalendarDay.startOfDay($0.date, calendar: calendar) }
            guard let day else { continue }

            // 24h due for sessions on this day (snooze already applied in PendingQueue).
            for session in PendingQueue.overdue(sessions: daySessions, now: now, calendar: calendar) {
                result.append(IncompleteItem(day: day, kind: .due24hResponse(sessionID: session.id)))
            }
            for draft in daySessions.filter(\.isDraft) {
                result.append(IncompleteItem(day: day, kind: .unfinishedDraft(sessionID: draft.id)))
            }

            let hasFootprint = checkByKey[key] != nil || !daySessions.isEmpty
            guard hasFootprint else { continue }
            let check = checkByKey[key]
            if check?.hasMorningPain != true {
                result.append(IncompleteItem(day: day, kind: .missingMorningPain))
            }
            if check?.hasEveningPain != true {
                result.append(IncompleteItem(day: day, kind: .missingEveningPain))
            }
        }
        return result
    }

    /// When nothing on Today is due, the earlier-day card can be the main prompt.
    static func becomesMainCard(todayAction: TodayNextAction) -> Bool {
        switch todayAction {
        case .allDone, .restDay:
            return true
        case .resolvePending, .logMorning, .logAfterPain, .logSession, .logEvening:
            return false
        }
    }

    /// Stable notification id. One reminder; replace the body when the list changes.
    static let notificationId = "incomplete-records"

    /// Fire at the next morning reminder (today if still ahead, else tomorrow).
    static func notificationFireDate(
        now: Date,
        amHour: Int,
        amMinute: Int,
        calendar: Calendar = .current
    ) -> Date {
        PendingQueue.nextMorningReminder(
            after: now,
            amHour: amHour,
            amMinute: amMinute,
            calendar: calendar
        )
    }

    static func shouldScheduleNotification(items: [IncompleteItem]) -> Bool {
        !items.isEmpty
    }
}
