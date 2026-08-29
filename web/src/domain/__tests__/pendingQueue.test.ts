import { describe, expect, it } from "vitest";
import { utcCalendar } from "../calendar";
import {
  overduePending,
  shouldScheduleNotification,
  todayPending,
} from "../pendingQueue";
import type { TrainingSessionSnapshot } from "../types";

const NOW = new Date(1_700_100_000 * 1000);

function snap(
  dayOffset: number,
  extra: Partial<TrainingSessionSnapshot> = {},
): TrainingSessionSnapshot {
  const today = utcCalendar.startOfDay(NOW);
  const day = utcCalendar.addDays(today, dayOffset);
  const date = utcCalendar.dayKey(day);
  return {
    id: crypto.randomUUID(),
    date,
    createdAt: day.toISOString(),
    sessionType: "isometrics",
    response24h: "pending",
    decision: null,
    resolvedAt: null,
    snoozedUntil: null,
    phase: "B",
    ...extra,
  };
}

describe("PendingQueue", () => {
  it("overdue oldest first", () => {
    const wed = snap(-1);
    const mon = snap(-3);
    const overdue = overduePending([wed, mon], NOW, utcCalendar);
    expect(overdue.map((s) => s.date)).toEqual([mon.date, wed.date]);
  });

  it("active snooze hides from overdue", () => {
    const until = new Date(NOW.getTime() + 3600_000).toISOString();
    const sessions = [snap(-2, { snoozedUntil: until })];
    expect(overduePending(sessions, NOW, utcCalendar)).toEqual([]);
  });

  it("today pending is not overdue", () => {
    const today = snap(0);
    expect(overduePending([today], NOW, utcCalendar)).toEqual([]);
    expect(todayPending([today], NOW, utcCalendar)).toHaveLength(1);
  });

  it("notification fire in past not scheduled", () => {
    expect(shouldScheduleNotification(new Date(NOW.getTime() - 3600_000), NOW)).toBe(false);
    expect(shouldScheduleNotification(new Date(NOW.getTime() + 3600_000), NOW)).toBe(true);
  });
});
