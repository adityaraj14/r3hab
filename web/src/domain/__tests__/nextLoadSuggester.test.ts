import { describe, expect, it } from "vitest";
import { suggestNextLoad } from "../nextLoadSuggester";

describe("nextLoadSuggester", () => {
  it("Stay keeps the same load", () => {
    const next = suggestNextLoad({
      lastLoadKg: 40,
      lastReps: 8,
      lastHoldSeconds: null,
      decision: "stay",
      unit: "kg",
    });
    expect(next.loadKg).toBe(40);
    expect(next.reps).toBe(8);
    expect(next.deltaLabel).toBe("same");
  });

  it("Progress adds 2.5 kg", () => {
    const next = suggestNextLoad({
      lastLoadKg: 40,
      lastReps: 8,
      lastHoldSeconds: null,
      decision: "progress",
      unit: "kg",
    });
    expect(next.loadKg).toBe(42.5);
    expect(next.deltaLabel).toBe("+2.5 kg");
  });

  it("SoftCut drops ~25% rounded to 2.5", () => {
    const next = suggestNextLoad({
      lastLoadKg: 40,
      lastReps: 8,
      lastHoldSeconds: 45,
      decision: "softCut",
      unit: "kg",
    });
    expect(next.loadKg).toBe(30);
    expect(next.holdSeconds).toBe(34);
    expect(next.deltaLabel).toBe("−25%");
  });

  it("null decision behaves as Stay", () => {
    const next = suggestNextLoad({
      lastLoadKg: 22.5,
      lastReps: null,
      lastHoldSeconds: 45,
      decision: null,
      unit: "kg",
    });
    expect(next.loadKg).toBe(22.5);
  });
});
