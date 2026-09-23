---
name: verify-r3hab
description: Verify R3hab domain behavior from this Linux or Mac checkout. Use when proving ProgressionEngine, prefill, or pain-gate changes. The iOS UI needs Xcode on a Mac.
---

# Verify R3hab

Personal offline iOS rehab logger. This checkout can prove the pure domain. The SwiftUI app needs Xcode.

## Launch

Domain tests:

```bash
./scripts/test-domain.sh
```

Ready when `swift test` prints `Test Suite 'ProgressionEngineTests' passed`.

iOS app, Mac only:

```bash
open R3hab.xcodeproj
```

There is no iOS simulator in this Linux environment. Do not claim Today or SessionEditor UI is proven here.

Teardown: none. `swift test` exits.

## Doctor

```bash
command -v swift
swift --version
test -f Package.swift && test -f R3hab/Domain/ProgressionEngine.swift
```

Fail if `swift` is missing or the engine file is gone.

## Drive

Run the real engine the way Today and SessionEditor call it.

```bash
./scripts/test-domain.sh
```

That filter is `ProgressionEngine.today`, `SessionPrefill.workSets`, and `ProgressionEngine.applySessionPain`.

## Evidence

Write stdout to `/tmp/r3hab-verify/domain-tests.txt`. Keep that file after cleanup.

Proof is a zero exit from `./scripts/test-domain.sh` plus these literals in the log:

- `testTwoCleanHitsAddFivePounds` passed
- `testPainDuringAboveThreeDropsLoad` passed
- `testWorseHoldsLoadAndSoftCutStaysAdvice` passed
- `testMissing24hHoldsAndAsks` passed
- `testMidLadderSnapsIntoBandAtSameLoad` passed
- `testPrefillBuildsEditableWorkingPairs` passed
- `testLegacyResistanceSetJSONDecodesWithoutPain` passed

## Cleanup

Remove `.build` only if you created it in a scratch clone. Never delete `/tmp/r3hab-verify`.

## Helpers

`./scripts/test-domain.sh` is the only helper. It fails loud when Swift is missing.
