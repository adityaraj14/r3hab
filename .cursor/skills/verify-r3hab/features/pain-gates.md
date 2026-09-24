# Pain gates

Option B. Pain is the session peak during the set, inclusive of 3. The 24h response is read by the engine.

## Sub-features

- `advance` when peak pain during is ≤3 and 24h is Better or Same, after two clean hits at the load
- `hold-worse` when 24h is Worse and pain is still ≤3. Soft cut stays DecisionSuggester advice and does not rewrite the load
- `drop` when peak pain during is above 3. Load steps down 5 lb to 3×8
- `hold-cta` when 24h is still pending. Reason is `Waiting on 24h check-in` and `pendingResolveID` is set

## How to get to it (user POV)

- Log a session, then resolve 24h
- Open Today the next lift day. The gold card shows Advance, Hold, or Drop plus one reason

## Driving it with swift test

Preconditions: domain tests pass.

- Run `./scripts/test-domain.sh`.
- Confirm `testPainDuringAboveThreeDropsLoad` passed. Pain 4 keeps the last load and says Decrease load. Reason `Pain during was 4`.
- Confirm `testPainThreeInclusiveStillAdvances` passed.
- Confirm `testWorseHoldsLoadAndSoftCutStaysAdvice` passed.
- Confirm `testMissing24hHoldsAndAsks` passed. The reason is not empty.

## Gotchas

Pain 3 still advances. Pain 4 drops. A missing 24h is a hold with a resolve id, never a silent hold. Next-morning AM and week-over-week creep do not decide the dose.
