import { describe, expect, it } from "vitest";
import { utcCalendar } from "../calendar";
import { prescribeToday } from "../prescription";
import { defaultSettings, type DailyCheckIn, type TrainingSession } from "../types";

const TODAY = utcCalendar.startOfDay(new Date(1_700_000_000 * 1000));

function key(offset: number): string {
  return utcCalendar.dayKey(utcCalendar.addDays(TODAY, offset));
}

describe("prescribeToday", () => {
  it("Phase A never prescribes extension", () => {
    const settings = { ...defaultSettings(), currentPhase: "A" as const };
    const p = prescribeToday({
      settings,
      checkIn: null,
      sessions: [],
      now: TODAY,
      calendar: utcCalendar,
    });
    expect(p.exerciseId).not.toContain("Extension");
    expect(p.kind === "walk" || p.kind === "rest").toBe(true);
    expect(p.isHard).toBe(false);
  });

  it("Phase C skips HSR on the day after HSR", () => {
    const settings = { ...defaultSettings(), currentPhase: "C" as const };
    const session: TrainingSession = {
      id: "hsr-y",
      date: key(-1),
      createdAt: `${key(-1)}T18:00:00.000Z`,
      updatedAt: `${key(-1)}T18:00:00.000Z`,
      phase: "C",
      sessionType: "hsrStrength",
      exerciseId: "seatedExtensionHsr",
      side: "both",
      kneeAngle: 60,
      tempo: "3-1-3",
      sets: [],
      painAfter: 2,
      notes: "",
      whatIDid: "HSR",
      response24h: "pending",
      decision: null,
      resolvedAt: null,
      snoozedUntil: null,
      snoozeUsed: false,
    };
    const p = prescribeToday({
      settings,
      checkIn: null,
      sessions: [session],
      now: TODAY,
      calendar: utcCalendar,
    });
    expect(p.kind).toBe("isoOffDay");
  });

  it("Phase B primary is seated extension isometric", () => {
    const settings = { ...defaultSettings(), currentPhase: "B" as const };
    const p = prescribeToday({
      settings,
      checkIn: null,
      sessions: [],
      now: TODAY,
      calendar: utcCalendar,
    });
    expect(p.kind).toBe("isoExtension");
    expect(p.exerciseId).toBe("seatedExtensionIso");
    expect(p.sets).toBe(5);
    expect(p.holdSeconds).toBe(45);
  });
});

describe("unused check-in type export", () => {
  it("compiles DailyCheckIn shape", () => {
    const row: DailyCheckIn = {
      dayKey: key(0),
      date: key(0),
      restingPainAM: 2,
      morningStiffness: 1,
      dailyPainPM: null,
      steps: 6000,
      declineSquatL: null,
      declineSquatR: null,
      notes: "",
      phase: "B",
      createdAt: "",
      updatedAt: "",
    };
    expect(row.restingPainAM).toBe(2);
  });
});
