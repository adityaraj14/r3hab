# R3hab

Personal offline-first iOS app for **patellar tendinopathy rehab logging**: daily pain check-ins, training sessions, and a forced 24-hour load–response decision loop.

> Not a medical device. Supports self-managed rehab logging; does not replace professional care.

## Design

Full requirements and implementation plan:

- [`DESIGN.md`](./DESIGN.md) — tagged REQs, data model, domain rules, PR plan

**Stack:** SwiftUI · SwiftData · iOS 17.0+ · local-only v1

**Notion** remains the protocol brain (phases, soft cut / hard drop copy). **R3hab** is the daily diary.

## Open in Xcode

```bash
open R3hab.xcodeproj
```

Select an iPhone simulator or device (iOS 17+), then Run (⌘R).

## Deep link (PR-08+)

```
r3hab://resolve?sessionId=<UUID>
```

(Design originally used `tendontrack://`; product name is **R3hab**, scheme will be `r3hab` when wired in PR-08.)

## Development

Incremental PR plan is in `DESIGN.md` § PR Plan.

- **Dogfood gate:** after pending 24h resolve (PR-08)
- **Export + import JSON:** PR-12

## License

Private personal project.
