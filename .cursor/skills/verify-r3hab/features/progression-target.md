# Progression target

Today asks the engine for the next seated-extension HSR dose. The user sees `Today: 3×10 @ 35 lbs` instead of doing the math.

## Sub-features

- `empty-history` starts at 3×8 with no load
- `two-clean-hits` advances one ladder step
- `user-history` at 35 lb 3×8 becomes 3×10 @ 35 lb
- `load-bump` after 4×12 adds 5 lb and returns to 4×8

## How to get to it (user POV)

- Today gold card `Log seated extension`
- Today entry row for seated extension when nothing is logged

## Driving it with swift test

Preconditions: `./scripts/test-domain.sh` is executable and `swift` works.

- Run `./scripts/test-domain.sh`. Expect exit 0.
- Confirm `testUserHistoryClimbsTowardThreeByTenAt35` passed. Expected target string is `Today: 3×10 @ 35 lbs`.
- Confirm `testLadderWalksToLoadBump` passed. Last step is 4×8 @ 40 lb.

## Gotchas

Iso holds and drafts do not count. A 6-row L/R log is 3 sets.
