# Pain gates

Pain up to 3 out of 10 during the exercise is fine. A next morning above the baseline drops the load 5 lb for one session. Pain over 3 warns and holds the load. A missing next morning holds and asks.

## Sub-features

- `morning-drop` when the next morning is above the baseline morning
- `pain-warn` when pain during is over 3 and the next morning is at baseline
- `missing-morning` holds the last load and sets `pendingResolveID` when the 24h response is still pending
- `weekly-increase` adds 5 lb on a new program week for the seated leg extension and the leg press when pain was at or under 3

## Driving it with swift test

- Run `./scripts/test-domain.sh`.
- Confirm `testNextMorningAboveBaselineDropsFivePoundsForOneSession` passed.
- Confirm `testPainAboveThreeWarnsAndDoesNotDropWhenTheMorningIsQuiet` passed.
- Confirm `testMissingMorningHoldsTheLoad` passed.
- Confirm `testNewWeekAddsFivePoundsAndUsesThatWeeksReps` passed.
