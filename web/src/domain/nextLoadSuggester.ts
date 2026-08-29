import type { LoadUnit, SessionDecision } from "./types";

const KG_PER_LB = 0.45359237;

export function incrementForUnit(unit: LoadUnit): number {
  return unit === "kg" ? 2.5 : 5;
}

export function roundToIncrement(value: number, increment: number): number {
  if (increment <= 0) return value;
  return Math.round(value / increment) * increment;
}

export function kgToDisplay(kg: number, unit: LoadUnit): number {
  if (unit === "kg") return roundToIncrement(kg, 2.5);
  return roundToIncrement(kg / KG_PER_LB, 5);
}

export function displayToKg(value: number, unit: LoadUnit): number {
  if (unit === "kg") return value;
  return value * KG_PER_LB;
}

export function formatLoad(kg: number, unit: LoadUnit): string {
  const v = kgToDisplay(kg, unit);
  const n = Number.isInteger(v) ? String(v) : v.toFixed(1).replace(/\.0$/, "");
  return `${n} ${unit}`;
}

export type NextLoadSuggestion = {
  loadKg: number;
  reps: number | null;
  holdSeconds: number | null;
  deltaLabel: string;
};

/**
 * Stay = same load.
 * Progress = +2.5 kg (or +5 lb) — one variable; reps stay unless lastLoad is null.
 * SoftCut = −25% (midpoint of −20–30%), rounded to plate increment.
 */
export function suggestNextLoad(args: {
  lastLoadKg: number;
  lastReps: number | null;
  lastHoldSeconds: number | null;
  decision: SessionDecision | null;
  unit: LoadUnit;
}): NextLoadSuggestion {
  const incKg = 2.5;
  const decision = args.decision ?? "stay";

  switch (decision) {
    case "progress":
      return {
        loadKg: roundToIncrement(args.lastLoadKg + incKg, incKg),
        reps: args.lastReps,
        holdSeconds: args.lastHoldSeconds,
        deltaLabel: args.unit === "lb" ? "+5 lb" : "+2.5 kg",
      };
    case "softCut": {
      const cut = Math.max(incKg, roundToIncrement(args.lastLoadKg * 0.75, incKg));
      const hold =
        args.lastHoldSeconds !== null
          ? Math.max(15, Math.round(args.lastHoldSeconds * 0.75))
          : null;
      return {
        loadKg: cut,
        reps: args.lastReps,
        holdSeconds: hold,
        deltaLabel: "−25%",
      };
    }
    default:
      return {
        loadKg: args.lastLoadKg,
        reps: args.lastReps,
        holdSeconds: args.lastHoldSeconds,
        deltaLabel: "same",
      };
  }
}

export function workSetsVolumeKgTut(args: {
  loadKg: number;
  holdSeconds: number | null;
  reps: number | null;
  tempoSecondsPerRep?: number;
}): number {
  const tut =
    args.holdSeconds !== null && args.holdSeconds > 0
      ? args.holdSeconds
      : (args.reps ?? 0) * (args.tempoSecondsPerRep ?? 7);
  return args.loadKg * tut;
}
