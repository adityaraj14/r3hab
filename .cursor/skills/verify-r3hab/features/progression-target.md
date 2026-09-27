# Progression target

Today asks the engine for stance advice. The form opens on the last working load. Two clean hits say Increase load. The gold card does not repeat the last dose; the entry row lists each set. A change-load reason names a weight only when the engine produced a load that differs from the last one. It does not today, so the reason stays `Two clean hits — increase load`.

## Sub-features

- `empty-history` starts at 3×8 with no load, stance Hold, reason "Start at 3×8"
- `two-clean-hits` advises Increase load and keeps the last working load as the prefill
- `landing-pad` snaps the set and rep shape into 3×8–12 at the same load
- `user-history` at 35 lb stays `3×8 @ 35 lbs` on the form; the card does not repeat that dose

## How to get to it (user POV)

- Today gold card `Log Workout`
- Today entry row for seated leg extension when nothing is logged

## Driving it with swift test

Preconditions: `./scripts/test-domain.sh` is executable and `swift` works.

- Run `./scripts/test-domain.sh`. Expect exit 0.
- Confirm `testTwoCleanHitsAdviseIncreaseWithoutChangingPrefill` passed. Prefill stays `3×8 @ 35 lbs`. Advice is `Increase load`.
- Confirm `testUserHistoryPrefillsLastLoadAndAdvisesIncrease` passed. Prefill display is `3×8 @ 35 lbs`. Card reason stays `Two clean hits — increase load`, with no last-time line.
- Confirm `testCardReasonNamesOnlyADistinctSuggestedWeight` passed. A hand-built 45 → 50 advance reads `Increase load: try 50 lbs`. Hold does not name a weight.

## Gotchas

Iso holds and drafts do not count. A 6-row L/R log is 3 sets. The old ladder `3×8→3×10→3×12→4×8→4×10→4×12` is not the suggestion path.
