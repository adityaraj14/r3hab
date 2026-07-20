# R3hab

Personal offline-first iOS app for **patellar tendinopathy rehab logging**: daily pain check-ins, training sessions, and a forced 24-hour load–response decision loop.

> Not a medical device. Supports self-managed rehab logging; does not replace professional care.

## Design

Full requirements and implementation plan:

- [`DESIGN.md`](./DESIGN.md) — tagged REQs, data model, domain rules, PR plan

**Stack:** SwiftUI · **SwiftData** (on-device SQLite) · iOS 17.0+ · local-only v1  

No remote backend. Export/import JSON is the backup path (PR-12).

**Notion** remains the protocol brain (phases, soft cut / hard drop copy). **R3hab** is the daily diary.

## Open in Xcode

```bash
open R3hab.xcodeproj
```

Select an iPhone simulator or device (iOS 17+), then Run (⌘R).

## Features (v1)

- Daily AM/PM check-in + steps
- Training sessions + **24h resolve** (Better/Same/Worse → Stay/Soft cut/Progress/Hard drop)
- Phase A exit banner, Progress charts (7/28 day)
- Settings: phase, thresholds, reminders, **JSON export/import**, **clear all logs**
- Onboarding + local notifications (AM/PM + pending 24h)
- Deep link / notification open → resolve sheet

## Deep link

```
r3hab://resolve?sessionId=<UUID>
```

## Backup

Settings → **Export JSON backup**. Import supports **Replace** or **Merge**.  
**Clear all log entries** wipes check-ins and sessions but keeps phase/settings.

## Dogfood checklist (14 days)

1. Log morning pain most days  
2. Log at least a few training sessions and resolve 24h next day  
3. Export a backup weekly  
4. Confirm notifications (if enabled) fire after a session  

## Development

Plan: `DESIGN.md` § PR Plan. Stack: SwiftUI + SwiftData, iOS 17+, dark mode only.

```bash
# Install on booted sim without launching
xcodebuild -scheme R3hab -destination 'platform=iOS Simulator,id=<UDID>' build
xcrun simctl install booted path/to/R3hab.app
```

## License

Private personal project.
