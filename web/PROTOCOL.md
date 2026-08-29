# R3hab protocol (web)

R3hab is a **patellar-tendinopathy-only** loading app. Progressive tendon loading + a 24-hour pain loop (Silbernagel / Rio / Kongsgaard / E3-style). Rest is not the treatment. The app **is** the protocol: today’s prescription, structured seated-extension logging, then 24h resolve.

The iOS app’s LOW BACK / QL dual-track is **intentionally gone** here. No quadratus lumborum, trunk, side plank, or dual-injury picker.

Not a medical device. Not a clinic UI.

## Phases (user-owned — the app suggests, never auto-advances)

| Phase | Do | Advance | Soft cut | Hard drop |
| --- | --- | --- | --- | --- |
| **A Flare / protect** | Relative rest. Walk toward 6–8k if AM pain ≤ threshold (default 2). Optional easy bike. **No** heavy extension, impact, or tennis. | 3 consecutive calendar days AM ≤ threshold **and** ≥1 of those days steps ≥ 6000. Missing day or nil AM breaks the streak. | Less walking | Red flags → clinician |
| **B Isometrics** | **Primary:** single-leg seated knee extension isometric at ~60°. Default 5 × 45s @ ~70%, 2 min rest, 1–2×/day possible but hard sessions ≥48h apart. Or Rio-style 5 sets of 4 × 3s max-effort pulses. Wall sit / Spanish squat are optional alts only. | ~4–6 clean 24h sessions (Better/Same), resting pain stays low | Shorter holds / fewer sets / −20–30% load | → A (confirm) |
| **C Heavy slow resistance** | **Primary:** single-leg seated knee extension. 3–4 × 6–15, tempo 3-1-3, 3×/week, never consecutive days. Pain ≤5/10 during is OK if next morning is not worse. Optional isometrics on off days. | Capacity up over months | −20–30% load or drop a set | → B or A (confirm) |
| **D Energy storage** | Low-volume landings/plyos **while** keeping 1–2 HSR extension days. Soft-cut plyo volume first if 24h worse. | Weeks of clean speed + stable HSR | Cut plyo volume | → C or A (confirm) |
| **E Return to tennis** | Graded hitting → match play. Keep 1–2 HSR extension days. **Never skip here from A/B.** | Desired tennis, stable 24h | Fewer tennis minutes | → C or A (confirm) |

Primary gym tool for isometrics **and** HSR: seated leg extension (isolates quads/tendon).

## 24h decision loop

Ported from `DESIGN.md` / the Swift domain (`DecisionSuggester`, `PendingQueue`).

- New sessions start **Pending**.
- Next morning (or early same evening) pick **Better / Same / Worse**.
- **Same** → Stay.
- **Better** → Stay, or **Progress** after 3 consecutive clean (Better/Same) non-Rest sessions by **session date** chronology (never `resolvedAt`).
- **Worse** → SoftCut first. **HardDrop** only if the immediate previous resolved non-Rest session (by date) was also Worse. Unresolved older Pendings do not count. This is the DESIGN.md multi-pending Worse vector.
- Rest path: decision=Rest, response=NotApplicable.
- Overdue pending (date < today) is a **priority queue**, not a hard gate. AM / PM / session always available.
- Hard sessions (iso / HSR / energy / tennis) ≥48h apart: **warn, do not block**.

Pain is integers 0–10. During-pain >5 is an amber/red warning, non-blocking. Next morning is the source of truth.

## Phase A exit

Ported from `PhaseAExitEvaluator` (KD-17). AND logic. Fixtures F1–F8 (+ F9 anchor) live in `src/domain/__tests__/phaseAExit.test.ts`.

## Load suggestions

- Stay = same load
- Progress = +2.5 kg (or +5 lb display)
- SoftCut = −25% (midpoint of −20–30%), rounded to plate increment
