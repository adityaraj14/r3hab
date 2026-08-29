# R3hab (web)

The current product. Patellar-tendinopathy rehab on your phone: today’s prescription, structured seated-extension logging, 24h load–response, and an interactive progress explorer.

Not a medical device. Protocol: [`PROTOCOL.md`](./PROTOCOL.md).

## Run it

```bash
cd web
npm install
npm test
npm run dev
```

Then open [http://localhost:3000](http://localhost:3000).

Dogfood without setup: [http://localhost:3000/demo](http://localhost:3000/demo) loads a ~21-day seed (B→C loads 20→45 kg, one SoftCut, one pending 24h) and sends you to Today.

| Script | What |
| --- | --- |
| `npm run dev` | Next.js dev server on `0.0.0.0:3000` |
| `npm test` | Domain unit tests (Vitest) |
| `npm run build` | Production build |
| `npm start` | Serve the build (`PORT` honored, bound to `0.0.0.0`) |

## Reviewer path (<3 minutes)

1. Skip onboarding (or hit `/demo`).
2. Read **Today’s prescription** → Start session → log **Left + Right** seated extension → Save.
3. Resolve the overdue **24h** card (Better / Same / Worse).
4. **Progress → Open explorer** → brush/zoom, toggle L/R load vs AM pain, tap a point.

## Stack

Next.js App Router · TypeScript · Tailwind v4 · Dexie (IndexedDB) · Recharts · PWA (manifest + service worker).

Client-only. No backend, no auth, no analytics. Airplane mode works after the first load.

## Vercel

Set the project **Root Directory** to `web`. `vercel.json` is in this folder.

## Install on iPhone

Safari → Share → Add to Home Screen. The forged-gold **3** is the icon. Offline after first load.

## DEBUG / demo

Settings → **Load demo week**. In development, the first visit auto-seeds if the database is empty.
