# R3hab

Personal offline-first iOS app for **patellar tendinopathy rehab**. Home shows the daily quote and one button to log a session. The log keeps past sessions and their training load. The guide is a short map of the rehab stages.

> Not a medical device. Supports self-managed rehab logging; does not replace professional care.

## Design

[`DESIGN.md`](./DESIGN.md) is the original 12-week diary spec. The app on this branch is the smaller logger: Home, Log, and Guide.

**Stack:** SwiftUI · **SwiftData** (on-device SQLite) · iOS 17.0+ · local-only

No remote backend. No reminders. Existing session rows stay in the on-device store.

## Open in Xcode

```bash
open R3hab.xcodeproj
```

Select an iPhone simulator or device (iOS 17+), then Run (⌘R).

## Screens

- **Home** — the daily quote, and **Log a session**
- **Guided log** — isometric leg extension holds, leg extension heavy sets, and leg press. Skip any exercise you did not do
- **Log** — past sessions, volume load, and a short trend
- **Guide** — isometrics, heavy slow resistance, energy storage, return to sport

Working-set load is reps × weight (lb). Isometric load is holds × seconds × weight (lb·s). Warm-ups are left out. A stored left/right pair with the same weight counts once.

## Development

Stack: SwiftUI + SwiftData, iOS 17+, dark mode only. Domain tests:

```bash
./scripts/test-domain.sh
swift test
```

```bash
# Install on booted sim without launching
xcodebuild -scheme R3hab -destination 'platform=iOS Simulator,id=<UDID>' build
xcrun simctl install booted path/to/R3hab.app
```

## License

Private personal project.
