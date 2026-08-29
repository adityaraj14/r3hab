import { type DayCalendar, localCalendar } from "./calendar";
import type { DailyCheckInSnapshot, PhaseSettingsSnapshot } from "./types";

export type PhaseAExitStatus = {
  stableDaysCount: number;
  stableDaysRequired: number;
  nearNormalStepDaysInStreak: number;
  needsNearNormalSteps: boolean;
  isReadyToAdvance: boolean;
  message: string;
};

/**
 * KD-17: AND only; consecutive calendar days; missing day / nil AM breaks streak.
 * Port of R3hab/Domain/PhaseAExitEvaluator.swift
 */
export function evaluatePhaseAExit(
  checkIns: DailyCheckInSnapshot[],
  settings: PhaseSettingsSnapshot,
  today: Date,
  calendar: DayCalendar = localCalendar,
): PhaseAExitStatus {
  const required = settings.phaseAStableDaysRequired;
  const painMax = settings.phaseAPainThreshold;
  const stepMin = settings.stepNearNormalMin;

  const byDay = new Map<string, DailyCheckInSnapshot>();
  for (const row of checkIns) {
    byDay.set(row.date, row);
  }

  const todayStart = calendar.startOfDay(today);
  const todayKey = calendar.dayKey(todayStart);
  const anchor = byDay.has(todayKey) ? todayStart : calendar.addDays(todayStart, -1);

  let stable = 0;
  let nearNormal = 0;
  let cursor = anchor;

  for (let i = 0; i < 60; i += 1) {
    const key = calendar.dayKey(cursor);
    const row = byDay.get(key);
    if (!row) break;
    if (row.restingPainAM === null || row.restingPainAM === undefined) break;
    if (row.restingPainAM > painMax) break;
    stable += 1;
    if (row.steps !== null && row.steps !== undefined && row.steps >= stepMin) {
      nearNormal += 1;
    }
    cursor = calendar.addDays(cursor, -1);
  }

  const needsSteps = nearNormal === 0;
  const ready = stable >= required && !needsSteps;

  let message: string;
  if (ready) {
    message = "Exit criteria looking good — switch to Phase B when ready (Settings)";
  } else if (stable >= required && needsSteps) {
    message = `${stable}/${required} stable · steps still low — aim ~6–8k when pain stays ≤${painMax}`;
  } else {
    const stepHint = needsSteps ? ` · Need a ~${Math.round(stepMin / 1000)}k+ step day in the streak` : "";
    message = `Stable mornings: ${stable}/${required}${stepHint}`;
  }

  return {
    stableDaysCount: stable,
    stableDaysRequired: required,
    nearNormalStepDaysInStreak: nearNormal,
    needsNearNormalSteps: needsSteps,
    isReadyToAdvance: ready,
    message,
  };
}
