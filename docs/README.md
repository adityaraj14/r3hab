# App Store pages (GitHub Pages)

Static HTML only — no build step, no JavaScript, no framework. These exist so App Store Connect has public Privacy Policy and Support URLs.

| File | Purpose | Public URL (once Pages is on) |
| --- | --- | --- |
| `index.html` | Landing with links | https://adityaraj14.github.io/r3hab/ |
| `privacy.html` | Privacy Policy | https://adityaraj14.github.io/r3hab/privacy.html |
| `support.html` | Support | https://adityaraj14.github.io/r3hab/support.html |

`.nojekyll` disables Jekyll processing so the files are served exactly as written.

## Turn on GitHub Pages (one time, after this lands on `main`)

1. Repo → **Settings** → **Pages** (left sidebar, under *Code and automation*).
2. Under **Build and deployment**, set **Source** to **Deploy from a branch**.
3. Branch: **`main`**, folder: **`/docs`**. Click **Save**.
4. Wait a minute, then open https://adityaraj14.github.io/r3hab/privacy.html. The Pages settings panel shows "Your site is live at …" when ready.

Equivalent CLI (needs a token with `repo`/Pages write scope):

```bash
gh api -X POST repos/adityaraj14/r3hab/pages \
  -f 'source[branch]=main' -f 'source[path]=/docs'
```

## App Store Connect

- **App Privacy → Privacy Policy URL:** `https://adityaraj14.github.io/r3hab/privacy.html`
- **App Information → Support URL:** `https://adityaraj14.github.io/r3hab/support.html`
- **Guideline 2.1 screen recording:** [`APP_REVIEW_DEMO.md`](./APP_REVIEW_DEMO.md). That file is the recording script. It is not a public support URL.

## Editing

Edit the HTML directly and bump the "Last updated" date in `privacy.html` when data practices change. Pushes to `main` redeploy automatically.
