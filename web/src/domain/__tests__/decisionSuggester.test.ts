import { describe, expect, it } from "vitest";
import { utcCalendar } from "../calendar";
import { priorsForSuggestion, suggestDecision } from "../decisionSuggester";
import type { TrainingSessionSnapshot } from "../types";

const TODAY = new Date(1_700_000_000 * 1000);

function session(args: {
  id?: string;
  dayOffset: number;
  response: TrainingSessionSnapshot["response24h"];
  decision?: TrainingSessionSnapshot["decision"];
  createdOffset?: number;
  resolvedOffset?: number;
}): TrainingSessionSnapshot {
  const day = utcCalendar.addDays(utcCalendar.startOfDay(TODAY), args.dayOffset);
  const date = utcCalendar.dayKey(day);
  const created = new Date(day.getTime() + (args.createdOffset ?? 0) * 1000).toISOString();
  const resolved =
    args.resolvedOffset === undefined
      ? new Date(day.getTime() + 86400000).toISOString()
      : new Date(day.getTime() + args.resolvedOffset * 1000).toISOString();
  return {
    id: args.id ?? crypto.randomUUID(),
    date,
    createdAt: created,
    sessionType: "isometrics",
    response24h: args.response,
    decision: args.decision ?? "stay",
    resolvedAt: args.response === "pending" ? null : resolved,
    snoozedUntil: null,
    phase: "B",
  };
}

describe("DecisionSuggester", () => {
  it("Better suggests Stay without clean streak", () => {
    expect(suggestDecision("better", [])).toBe("stay");
  });

  it("Better suggests Progress after three clean", () => {
    expect(suggestDecision("better", ["same", "better", "same"])).toBe("progress");
  });

  it("Same always Stay", () => {
    expect(suggestDecision("same", ["better", "better", "better"])).toBe("stay");
  });

  it("first Worse is SoftCut", () => {
    expect(suggestDecision("worse", [])).toBe("softCut");
  });

  it("second Worse is HardDrop", () => {
    expect(suggestDecision("worse", ["worse"])).toBe("hardDrop");
  });

  it("two Worse uses session date not resolve order (DESIGN Mon/Wed/Fri vector)", () => {
    const mon = session({ dayOffset: -4, response: "pending", decision: null });
    const wed = session({ dayOffset: -2, response: "pending", decision: null });
    const fri = session({ dayOffset: 0, response: "pending", decision: null });

    const suggestWed = suggestDecision(
      "worse",
      priorsForSuggestion(wed, [mon, wed, fri]),
    );
    expect(suggestWed).toBe("softCut");

    const monResolved: TrainingSessionSnapshot = {
      ...mon,
      response24h: "worse",
      decision: "softCut",
      resolvedAt: new Date(TODAY.getTime() + 3 * 86400000).toISOString(),
    };
    const wedResolved: TrainingSessionSnapshot = {
      ...wed,
      response24h: "worse",
      decision: "softCut",
      resolvedAt: new Date(TODAY.getTime() - 86400000).toISOString(),
    };

    const suggestFri = suggestDecision(
      "worse",
      priorsForSuggestion(fri, [monResolved, wedResolved, fri]),
    );
    expect(suggestFri).toBe("hardDrop");
  });

  it("resolvedAt order is ignored for HardDrop", () => {
    const older = session({
      dayOffset: -2,
      response: "worse",
      decision: "softCut",
      resolvedOffset: 200000,
    });
    const current = session({ dayOffset: 0, response: "pending", decision: null });
    const priors = priorsForSuggestion(current, [older, current]);
    expect(priors[0]).toBe("worse");
    expect(suggestDecision("worse", priors)).toBe("hardDrop");
  });

  it("Rest sessions excluded from priors", () => {
    const rest = session({
      dayOffset: -1,
      response: "notApplicable",
      decision: "rest",
    });
    const current = session({ dayOffset: 0, response: "pending", decision: null });
    const priors = priorsForSuggestion(current, [rest, current]);
    expect(priors).toEqual([]);
  });
});
