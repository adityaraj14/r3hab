# Pain gates

Advance needs all four gates. Failures hold or drop one step.

## Sub-features

- `consecutive-reps` needs two completed top-rep sessions at this level
- `pain-during` fails above 5, including a single hot set
- `next-morning` fails when AM rises vs the session-day baseline
- `wow-creep` fails when this week's AM mean is at least 1.0 above last week's

## How to get to it (user POV)

- Log a session, then log the next morning's AM
- Open Today the next lift day

## Driving it with swift test

Preconditions: domain tests pass.

- Run `./scripts/test-domain.sh`.
- Confirm `testPainDuringAboveFiveDropsOneStep` passed. 3×10 @ 35 with pain 6 becomes 3×8 @ 35.
- Confirm `testNextMorningAboveBaselineDrops` passed.
- Confirm `testWeekOverWeekCreepDrops` passed.
- Confirm `testUnknownNextMorningBlocksAdvanceWithoutDrop` passed. Unknown AM holds.

## Gotchas

Pain 5 still advances. Missing next-morning AM is a hold, not a drop.
