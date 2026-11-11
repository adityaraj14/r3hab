# Progression target

Today asks the 12-week plan for the dose. Reps come from the week. Load goes up 5 lb on a new week for the two heavy lifts, and down 5 lb for one session when the next morning is above baseline.

## Sub-features

- `week-one` starts on the seated hold, 5×45 seconds, no load
- `week-three` starts at 4×15 with a 3-second tempo
- `rep-ramp` is 15, 13, 12, 10, then 8, 7, 7, 6
- `no-jumping` before week 11

## Driving it with swift test

- Run `./scripts/test-domain.sh`.
- Confirm `testRepRamp` passed.
- Confirm `testNoRunningOrHighVolumeJumpingBeforeWeekEleven` passed.
- Confirm `testWeekThreeEmptyHistoryUsesFourByFifteen` passed.
