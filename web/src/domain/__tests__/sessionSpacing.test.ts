import { describe, expect, it } from "vitest";
import {
  hoursSinceLastHard,
  isHardSession,
  shouldWarnUnder48h,
} from "../sessionSpacing";
import type { TrainingSessionSnapshot } from "../types";

function snap(
  hoursAgo: number,
  type: TrainingSessionSnapshot["sessionType"] = "isometrics",
): TrainingSessionSnapshot {
  const now = 1_700_100_000 * 1000;
  const created = new Date(now - hoursAgo * 3600_000);
  return {
    id: crypto.randomUUID(),
    date: created.toISOString().slice(0, 10),
    createdAt: created.toISOString(),
    sessionType: type,
    response24h: "pending",
    decision: null,
    resolvedAt: null,
    snoozedUntil: null,
    phase: "B",
  };
}

describe("SessionSpacing", () => {
  it("iso / HSR / energy / tennis are hard; other is not", () => {
    expect(isHardSession("isometrics")).toBe(true);
    expect(isHardSession("hsrStrength")).toBe(true);
    expect(isHardSession("energyStorage")).toBe(true);
    expect(isHardSession("tennisSport")).toBe(true);
    expect(isHardSession("other")).toBe(false);
  });

  it("warns under 48h for a hard session", () => {
    const now = new Date(1_700_100_000 * 1000);
    const sessions = [snap(24)];
    expect(shouldWarnUnder48h(sessions, "hsrStrength", now)).toBe(true);
    expect(shouldWarnUnder48h(sessions, "other", now)).toBe(false);
  });

  it("does not warn after 48h", () => {
    const now = new Date(1_700_100_000 * 1000);
    const sessions = [snap(50)];
    expect(shouldWarnUnder48h(sessions, "isometrics", now)).toBe(false);
    const hours = hoursSinceLastHard(sessions, now);
    expect(hours).toBeGreaterThan(48);
  });
});
