import { describe, expect, it } from "vitest";
import { utcCalendar } from "../calendar";
import {
  loadSeriesBySide,
  painSeries,
  volumeSeries,
} from "../chartAggregates";
import type { DailyCheckIn, TrainingSession } from "../types";

const TODAY = utcCalendar.startOfDay(new Date(1_700_000_000 * 1000));

function key(offset: number): string {
  return utcCalendar.dayKey(utcCalendar.addDays(TODAY, offset));
}

function checkIn(offset: number, am: number | null, steps: number | null): DailyCheckIn {
  const dayKey = key(offset);
  return {
    dayKey,
    date: dayKey,
    restingPainAM: am,
    morningStiffness: null,
    dailyPainPM: offset === 0 ? 3 : null,
    steps,
    declineSquatL: null,
    declineSquatR: null,
    notes: "",
    phase: "C",
    createdAt: `${dayKey}T08:00:00.000Z`,
    updatedAt: `${dayKey}T08:00:00.000Z`,
  };
}

function session(
  offset: number,
  loadL: number,
  loadR: number,
  hold = 0,
  reps = 8,
): TrainingSession {
  const dayKey = key(offset);
  return {
    id: `s-${offset}`,
    date: dayKey,
    createdAt: `${dayKey}T18:00:00.000Z`,
    updatedAt: `${dayKey}T18:00:00.000Z`,
    phase: "C",
    sessionType: "hsrStrength",
    exerciseId: "seatedExtensionHsr",
    side: "both",
    kneeAngle: 60,
    tempo: "3-1-3",
    sets: [
      {
        id: "L0",
        side: "L",
        loadKg: loadL,
        holdSeconds: hold || null,
        reps: hold ? null : reps,
        painDuring: 2,
        isWarmup: false,
      },
      {
        id: "R0",
        side: "R",
        loadKg: loadR,
        holdSeconds: hold || null,
        reps: hold ? null : reps,
        painDuring: 2,
        isWarmup: false,
      },
    ],
    painAfter: 2,
    notes: "",
    whatIDid: "Seated extension",
    response24h: "same",
    decision: "stay",
    resolvedAt: `${dayKey}T20:00:00.000Z`,
    snoozedUntil: null,
    snoozeUsed: false,
  };
}

describe("chartAggregates", () => {
  it("pain series fills gaps", () => {
    const rows = [checkIn(-2, 2, 5000), checkIn(0, 1, 6000)];
    const series = painSeries(rows, "restingAM", 3, TODAY, utcCalendar);
    expect(series).toHaveLength(3);
    expect(series[0].value).toBe(2);
    expect(series[1].value).toBeNull();
    expect(series[2].value).toBe(1);
  });

  it("load series is side-separated and takes max per day", () => {
    const sessions = [
      session(-2, 20, 22.5),
      session(-2, 25, 20),
      session(0, 30, 35),
    ];
    sessions[1].id = "s-2b";
    const left = loadSeriesBySide(sessions, "L", 3, TODAY, utcCalendar);
    const right = loadSeriesBySide(sessions, "R", 3, TODAY, utcCalendar);
    expect(left[0].value).toBe(25);
    expect(right[0].value).toBe(22.5);
    expect(left[1].value).toBeNull();
    expect(left[2].value).toBe(30);
    expect(right[2].value).toBe(35);
  });

  it("volume is sets × load × time-under-tension", () => {
    const sessions = [session(0, 10, 10, 0, 2)];
    const vol = volumeSeries(sessions, 1, TODAY, utcCalendar);
    // 2 sides × 10 kg × 2 reps × 7s tempo = 280
    expect(vol[0].value).toBe(280);
  });
});
