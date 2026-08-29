import { describe, expect, it } from "vitest";
import { parseBackup, serializeBackup } from "../../data/exportImport";
import { defaultSettings } from "../types";

describe("exportImport schemaVersion 2", () => {
  it("round-trips structured sets", () => {
    const json = serializeBackup({
      settings: defaultSettings(),
      checkIns: [],
      sessions: [
        {
          id: "abc",
          date: "2026-08-01",
          createdAt: "2026-08-01T18:00:00.000Z",
          updatedAt: "2026-08-01T18:00:00.000Z",
          phase: "C",
          sessionType: "hsrStrength",
          exerciseId: "seatedExtensionHsr",
          side: "both",
          kneeAngle: 60,
          tempo: "3-1-3",
          sets: [
            {
              id: "s1",
              side: "L",
              loadKg: 40,
              holdSeconds: null,
              reps: 8,
              painDuring: 2,
              isWarmup: false,
            },
          ],
          painAfter: 2,
          notes: "",
          whatIDid: "HSR",
          response24h: "pending",
          decision: null,
          resolvedAt: null,
          snoozedUntil: null,
          snoozeUsed: false,
        },
      ],
    });
    const parsed = parseBackup(json);
    expect(parsed.schemaVersion).toBe(2);
    expect(parsed.trainingSessions[0].sets[0].loadKg).toBe(40);
  });

  it("rejects unknown schemaVersion", () => {
    expect(() => parseBackup(JSON.stringify({ schemaVersion: 99 }))).toThrow(
      /Unsupported backup version/,
    );
  });
});
