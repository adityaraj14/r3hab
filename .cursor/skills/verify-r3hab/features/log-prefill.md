# Log prefill

Opening a new HSR log fills working sets from the engine. Every field stays editable.

## Sub-features

- `prefill-pairs` builds 3 L/R pairs at the target reps and load
- `save-paints-pain` copies session pain onto sets that have none
- `legacy-json` loads old set rows with nil per-set pain

## How to get to it (user POV)

- Tap `Log Workout` on Today
- Save a completed session

## Driving it with swift test

Preconditions: domain tests pass.

- Run `./scripts/test-domain.sh`.
- Confirm `testPrefillBuildsEditableWorkingPairs` passed. 6 rows, reps 10, load 35.
- Confirm `testSaveCopiesSessionPainOntoSetsWithoutPain` passed. Existing 4 stays, others become 2.
- Confirm `testLegacyResistanceSetJSONDecodesWithoutPain` passed.

## Gotchas

A draft on Today opens the draft, not a fresh engine seed.
