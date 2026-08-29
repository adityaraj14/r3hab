import { describe, expect, it } from "vitest";
import { utcCalendar } from "../calendar";
import { evaluatePhaseAExit } from "../phaseAExit";
import type { DailyCheckInSnapshot, PhaseSettingsSnapshot } from "../types";
import { DEFAULT_PHASE_SETTINGS } from "../types";

const settings: PhaseSettingsSnapshot = {
  ...DEFAULT_PHASE_SETTINGS,
  currentPhase: "A",
  phaseAPainThreshold: 2,
  phaseAStableDaysRequired: 3,
  stepNearNormalMin: 6000,
};

const TODAY = new Date(1_700_000_000 * 1000);

function snap(dayOffset: number, am: number | null, steps: number | null): DailyCheckInSnapshot {
  const day = utcCalendar.addDays(utcCalendar.startOfDay(TODAY), dayOffset);
  return { date: utcCalendar.dayKey(day), restingPainAM: am, steps };
}

describe("PhaseAExitEvaluator F1–F9", () => {
  it("F1 empty", () => {
    const status = evaluatePhaseAExit([], settings, TODAY, utcCalendar);
    expect(status.stableDaysCount).toBe(0);
    expect(status.isReadyToAdvance).toBe(false);
  });

  it("F2 two stable days steps low", () => {
    const checkIns = [snap(-1, 2, 5000), snap(0, 2, 5000)];
    const status = evaluatePhaseAExit(checkIns, settings, TODAY, utcCalendar);
    expect(status.stableDaysCount).toBe(2);
    expect(status.nearNormalStepDaysInStreak).toBe(0);
    expect(status.isReadyToAdvance).toBe(false);
  });

  it("F3 classic ready", () => {
    const checkIns = [snap(-2, 2, 5000), snap(-1, 2, 5000), snap(0, 2, 7000)];
    const status = evaluatePhaseAExit(checkIns, settings, TODAY, utcCalendar);
    expect(status.stableDaysCount).toBe(3);
    expect(status.nearNormalStepDaysInStreak).toBe(1);
    expect(status.isReadyToAdvance).toBe(true);
  });

  it("F4 all near-normal ready", () => {
    const checkIns = [snap(-2, 2, 7000), snap(-1, 2, 7000), snap(0, 2, 7000)];
    const status = evaluatePhaseAExit(checkIns, settings, TODAY, utcCalendar);
    expect(status.stableDaysCount).toBe(3);
    expect(status.nearNormalStepDaysInStreak).toBe(3);
    expect(status.isReadyToAdvance).toBe(true);
  });

  it("F5 gap breaks streak", () => {
    const checkIns = [snap(-2, 2, 7000), snap(0, 2, 7000)];
    const status = evaluatePhaseAExit(checkIns, settings, TODAY, utcCalendar);
    expect(status.stableDaysCount).toBe(1);
    expect(status.isReadyToAdvance).toBe(false);
  });

  it("F6 nil AM breaks", () => {
    const checkIns = [snap(-2, 2, 7000), snap(-1, null, 7000), snap(0, 2, 7000)];
    const status = evaluatePhaseAExit(checkIns, settings, TODAY, utcCalendar);
    expect(status.stableDaysCount).toBe(1);
    expect(status.isReadyToAdvance).toBe(false);
  });

  it("F7 pain 3 breaks", () => {
    const checkIns = [snap(-2, 2, 7000), snap(-1, 3, 7000), snap(0, 2, 7000)];
    const status = evaluatePhaseAExit(checkIns, settings, TODAY, utcCalendar);
    expect(status.stableDaysCount).toBe(1);
    expect(status.isReadyToAdvance).toBe(false);
  });

  it("F8 near-normal on older day in streak", () => {
    const checkIns = [snap(-2, 1, 8000), snap(-1, 2, 4000), snap(0, 2, 4000)];
    const status = evaluatePhaseAExit(checkIns, settings, TODAY, utcCalendar);
    expect(status.stableDaysCount).toBe(3);
    expect(status.nearNormalStepDaysInStreak).toBe(1);
    expect(status.isReadyToAdvance).toBe(true);
  });

  it("F9 anchor yesterday when today missing", () => {
    const checkIns = [snap(-3, 2, 7000), snap(-2, 2, 7000), snap(-1, 2, 7000)];
    const status = evaluatePhaseAExit(checkIns, settings, TODAY, utcCalendar);
    expect(status.stableDaysCount).toBe(3);
    expect(status.isReadyToAdvance).toBe(true);
  });
});
