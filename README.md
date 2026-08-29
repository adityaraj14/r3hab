# R3hab

Personal patellar-tendinopathy rehab app. Progressive tendon loading + a 24-hour pain loop.

> Not a medical device. Supports self-managed rehab logging; does not replace professional care.

## Current product: web

The **current product** lives in [`web/`](./web/) — a Next.js App Router PWA you can launch in a browser (and install on a phone) without Xcode.

```bash
cd web
npm install
npm test
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). Reviewer shortcut: [`/demo`](./web/README.md) seeds a week of real-looking data.

Details, protocol, and Vercel notes: [`web/README.md`](./web/README.md) · [`web/PROTOCOL.md`](./web/PROTOCOL.md).

## iOS (legacy)

The SwiftUI + SwiftData iPhone app remains in this repo (`R3hab/`, `R3hab.xcodeproj`) and is **not** the primary product. Original diary spec: [`DESIGN.md`](./DESIGN.md) (working name TendonTrack). The web app is the protocol, not a port of the diary UI. Low-back / QL dual-track from later iOS work is **not** in the web app.

```bash
open R3hab.xcodeproj
```

## License

Private personal project.
