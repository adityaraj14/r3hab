# Progression target

Today asks the engine for the next seated-extension HSR dose. Two clean hits step the load. The user sees `Today: 3×8 @ 40 lbs` instead of a volume rung.

## Sub-features

- `empty-history` starts at 3×8 with no load, stance Hold, reason "Start at 3×8"
- `two-clean-hits` adds 5 lb and lands at 3×8 when pain during is ≤3 and 24h is Better or Same
- `landing-pad` after a new load can do one same-load step, 3×8 → 3×10, then +5
- `user-history` at 35 lb 3×8 becomes 3×8 @ 40 lb

## How to get to it (user POV)

- Today gold card `Log Workout`
- Today entry row for seated leg extension when nothing is logged

## Driving it with swift test

Preconditions: `./scripts/test-domain.sh` is executable and `swift` works.

- Run `./scripts/test-domain.sh`. Expect exit 0.
- Confirm `testTwoCleanHitsAddFivePounds` passed. Target is `3×8 @ 40 lbs`, reason `Two clean hits — +5 lb`.
- Confirm `testLongVolumeLadderIsNotTheSuggestionPath` passed. No rung climbs toward 4×12.
- Confirm `testUserHistoryStepsFivePoundsInsteadOfThreeByTen` passed. Today line is `Today: 3×8 @ 40 lbs`.

## Gotchas

Iso holds and drafts do not count. A 6-row L/R log is 3 sets. The old ladder `3×8→3×10→3×12→4×8→4×10→4×12` is not the suggestion path.
