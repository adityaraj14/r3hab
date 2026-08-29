import { type DayCalendar, localCalendar } from "./calendar";
import type { TrainingSessionSnapshot } from "./types";

/**
 * Port of R3hab/Domain/PendingQueue.swift
 */
export function overduePending(
  sessions: TrainingSessionSnapshot[],
  now: Date,
  calendar: DayCalendar = localCalendar,
): TrainingSessionSnapshot[] {
  const todayKey = calendar.dayKey(now);
  return sessions
    .filter((session) => {
      if (session.response24h !== "pending") return false;
      if (!(session.date < todayKey)) return false;
      if (session.snoozedUntil && Date.parse(session.snoozedUntil) > now.getTime()) return false;
      return true;
    })
    .sort((a, b) => {
      if (a.date !== b.date) return a.date < b.date ? -1 : 1;
      return a.createdAt < b.createdAt ? -1 : 1;
    });
}

export function todayPending(
  sessions: TrainingSessionSnapshot[],
  now: Date,
  calendar: DayCalendar = localCalendar,
): TrainingSessionSnapshot[] {
  const todayKey = calendar.dayKey(now);
  return sessions
    .filter((session) => session.response24h === "pending" && session.date === todayKey)
    .sort((a, b) => (a.createdAt < b.createdAt ? -1 : 1));
}

export function nextMorningReminder(
  after: Date,
  amHour: number,
  amMinute: number,
  calendar: DayCalendar = localCalendar,
): Date {
  const start = calendar.startOfDay(after);
  const todayMorning = withTime(start, amHour, amMinute, calendar);
  if (todayMorning.getTime() > after.getTime()) return todayMorning;
  return withTime(calendar.addDays(start, 1), amHour, amMinute, calendar);
}

export function notificationFireDate(
  sessionDate: Date,
  amHour: number,
  amMinute: number,
  calendar: DayCalendar = localCalendar,
): Date {
  const day = calendar.startOfDay(sessionDate);
  return withTime(calendar.addDays(day, 1), amHour, amMinute, calendar);
}

export function shouldScheduleNotification(fireAt: Date, now: Date): boolean {
  return fireAt.getTime() > now.getTime();
}

function withTime(day: Date, hour: number, minute: number, calendar: DayCalendar): Date {
  if (calendar === localCalendar) {
    const d = new Date(day.getTime());
    d.setHours(hour, minute, 0, 0);
    return d;
  }
  return new Date(
    Date.UTC(day.getUTCFullYear(), day.getUTCMonth(), day.getUTCDate(), hour, minute, 0, 0),
  );
}
