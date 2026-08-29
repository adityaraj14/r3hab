import type { RehabPhase } from "./types";

export const PHASE_RULES: Record<
  RehabPhase,
  { do: string; advance: string; softCut: string; hardDrop: string }
> = {
  A: {
    do: "Relative rest. Walk toward 6–8k if AM pain ≤ threshold. Optional easy bike. No heavy extension, no impact, no tennis.",
    advance:
      "3 consecutive calendar days AM pain ≤ threshold (default 2) AND ≥1 of those days steps ≥ 6000. Missing day or nil AM breaks the streak. You switch the phase.",
    softCut: "Less walking.",
    hardDrop: "Medical red flags — see a clinician.",
  },
  B: {
    do: "PRIMARY: single-leg seated knee extension isometric at ~60°. Default 5 × 45s @ ~70%, 2 min rest; or Rio 5 × (4 × 3s) pulses. Wall sit / Spanish squat are optional alts only.",
    advance: "After ~4–6 clean 24h sessions (Better/Same) and resting pain stays low. You switch it.",
    softCut: "Shorter holds, fewer sets, or −20–30% load.",
    hardDrop: "Back to A when you confirm.",
  },
  C: {
    do: "PRIMARY: single-leg seated knee extension HSR. 3–4 × 6–15, tempo 3-1-3, 3×/week, never consecutive days. Pain ≤5/10 during is OK if next morning is not worse. Optional iso on off days.",
    advance: "Capacity up, life stable, then energy storage. Months. You switch it.",
    softCut: "−20–30% load or drop a set.",
    hardDrop: "Back to B (or A) when you confirm.",
  },
  D: {
    do: "Low-volume landings/plyos WHILE keeping 1–2 HSR extension days.",
    advance: "Weeks of clean 24h on speed + stable HSR. You switch it.",
    softCut: "Cut plyo volume first if 24h worse.",
    hardDrop: "Back to C (or A) when you confirm.",
  },
  E: {
    do: "Graded hitting → match play. Keep 1–2 HSR extension days as maintenance. Never skip here from A/B.",
    advance: "Desired tennis with stable 24h.",
    softCut: "Fewer tennis minutes.",
    hardDrop: "Back to C (or A) when you confirm.",
  },
};

export const RED_FLAGS =
  "See a clinician if: resting pain 5+, no improvement after 7–10 days of de-load, swelling, locking, instability, or sharp joint pain (not usual tendon ache).";
