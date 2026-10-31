# Marketing site Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A static site at `getloomia.app` (Home, Privacy, Support, Legal notice, EN + FR) that gives the App Store and Play their privacy and support URLs and roughly shows the app.

**Architecture:** A new public repo `paulthvt/loomia-site`. Astro builds plain HTML (no client JavaScript) into `dist/`, served by a Cloudflare Worker with static assets only, on the custom domain `getloomia.app`. GitHub Actions builds and checks every PR and deploys `main`. One Node script with `node:test` checks the built HTML; there is no browser test stack.

**Tech Stack:** Astro 7.4.4, @astrojs/sitemap 3.7.4, wrangler 4.147.0 (same pin as the app), Node 24 LTS in CI, plain CSS.

**Spec:** `docs/superpowers/specs/2026-10-30-marketing-site-design.md` (app repo). Figma: [Marketing site — #121](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=480-15628).

## Global Constraints

- Paths `/`, `/privacy`, `/support`, `/legal`, and the same under `/fr`. No trailing slash. English at the root. No language detection or redirect.
- French in *tu*, never *vous*. No "recruit", rank, downline, PV/OV, "Elite", essential oils, income claims, counters, testimonials or store badges anywhere in the output.
- No `<script>` in any built page. No cookies, no analytics.
- Colours only from the app's tokens (design-system.md §1), as CSS custom properties; site-only additions are scale, spacing and widths (spec → Site look). Light/dark from `prefers-color-scheme`, no toggle.
- Contact `hello@getloomia.app` everywhere; publisher Paul Thevenot as an individual, no SIRET yet.
- Exact dependency pins (`"astro": "7.4.4"`, no `^`), `package-lock.json` committed. Node and npm stay inside `loomia-site`; nothing is added to the app repo but this plan and the spec.
- Conventional Commits; PR titles under 70 characters; the PR says `Closes paulthvt/loomia#121`.

## Rulings made while planning

- **Text pages are Markdown** (`src/pages/privacy.md` with a `layout`), the home page is an Astro component fed by `src/i18n.ts`. Legal text reads best as prose files; the home page needs structure.
- **The wordmark is HTML, not an image:** "l", an inline SVG mark, "omia" in Plus Jakarta Sans Bold, like `lib/core/ui/loomia_mark.dart`. One SVG (`src/components/Mark.astro`) carries the geometry of `tool/brand/icons.sh`; the app's Brand page note and `icons.sh` header gain "and loomia-site/src/components/Mark.astro".
- **Screenshots come from the iPhone simulator,** signed in to a demo account with neutral data, captured with `xcrun simctl io booted screenshot`, light and dark via `xcrun simctl ui booted appearance`. No screenshot tooling is added. Converted to WebP with `cwebp` (already installed).
- **The font is the app's TTF,** copied from `assets/fonts/PlusJakartaSans.ttf` (176 KB, variable). ponytail: no woff2 conversion; do it if page weight matters.
- **The OG image** is rendered once from `og.html` with headless Chrome and committed. No image pipeline.
- **A 404 page** (`src/pages/404.astro`, both languages on one page) though the spec is silent: Workers serves it for unknown paths.
- **`build.format: 'file'`** so `/privacy` maps to `privacy.html`; Workers' default `html_handling` serves it without the extension and redirects `/privacy/` and `/privacy.html` to `/privacy`.

## Deviations while building

- **Screenshots from the web app, not the simulator:** sign-in failed on the
  simulator, and the local web build of `main` was newer than
  `app.getloomia.app`. Taken with playwright at 393×852, 3x, pointer parked in
  the header (no tooltip, hover or scrollbar). They live in `public/shots/`
  (plain `<img>`), not `src/assets/shots/`.
- **French screenshots too** (`public/shots/fr/`): the French page shows the
  French app. The demo data's workflow and step names are in English, so they
  stay English in both.
- **The test skips pages that aren't built** and lets "every page is built"
  report them, so one missing page doesn't fail every check.

## Review Focus

1. A 320 px wide phone with the French headline: nothing scrolls sideways; long words wrap. (Task 4 step: screenshot at 320 px.)
2. Dark mode: the wordmark letters flip, the mark stays `#E8964A`, the screenshots switch to their dark versions. (Task 4 check: every `<picture>` has a `prefers-color-scheme: dark` source.)
3. Keyboard only: every link and button reachable, focus ring visible on the ochre button and on text links. (Task 1 CSS + Task 4 manual step.)
4. `/privacy/`, `/privacy.html` and an unknown path after deploy: the first two land on `/privacy`, the last gets the 404 page with status 404. (Task 6 curl step.)
5. The language link on every page goes to the same page in the other language, not to the home page. (Task 2 check.)

---

### Task 0: Prerequisites (Paul, by hand)

- [x] **Step 1: Email Routing.** Cloudflare → `getloomia.app` → Email → Email Routing → enable, add the records it proposes, and a rule `hello@getloomia.app` → Paul's Gmail. Expected: a test mail to `hello@` arrives.
- [x] **Step 2: Demo account.** On `app.getloomia.app`, sign up with a Gmail plus-address (`<you>+demo@gmail.com`), business model **Other**. Enter neutral data: about eight contacts with invented names, two workflows, a "Product evening" and a "Spring open house" event with people invited and one marked as there, three tasks ("Print the price list", "Order flyers", "Call the supplier"), a month plan with goals in customers and new contacts only, no volume, no level. Nothing from a real person. Keep the credentials: App Store review (#398) needs a demo account too.

### Task 1: Repo, layout and the check script

**Files:**
- Create (repo `paulthvt/loomia-site`): `package.json`, `package-lock.json`, `astro.config.mjs`, `wrangler.jsonc`, `.gitignore`, `.nvmrc` (`24`), `README.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `src/styles/site.css`, `src/layouts/Base.astro`, `src/components/Mark.astro`, `src/components/Wordmark.astro`, `src/components/Header.astro`, `src/components/Footer.astro`, `src/i18n.ts`, `public/fonts/PlusJakartaSans.ttf`, `public/favicon.svg`, `public/favicon.png`, `public/apple-touch-icon.png`, `public/robots.txt`
- Test: `test/site.test.mjs`

**Interfaces:**
- Produces: `type Lang = 'en' | 'fr'`; `t(lang: Lang)` returning the string table for header, footer and home; `altPath(path: string): string` (`/privacy` ↔ `/fr/privacy`, `/` ↔ `/fr`); `<Base lang title description path>` layout with header, footer, canonical, hreflang; `pages(): string[]` in the test, the eight expected paths.

- [x] **Step 1: Create the repo and scaffold.** `gh repo create paulthvt/loomia-site --public --add-readme --description "getloomia.app"`, clone into `~/dev/git/perso/loomia-site`, `npm init -y`, `npm install --save-exact astro@7.4.4 @astrojs/sitemap@3.7.4`. Scripts: `"build": "astro build"`, `"test": "node --test test/"`, `"check": "npm run build && npm test"`. Copy the font, `web/favicon.png` and `web/icons/apple-touch-icon.png` from the app repo.
- [x] **Step 2: `astro.config.mjs`:** `site: 'https://getloomia.app'`, `trailingSlash: 'never'`, `build: { format: 'file' }`, `i18n: { locales: ['en', 'fr'], defaultLocale: 'en', routing: { prefixDefaultLocale: false } }`, `integrations: [sitemap({ i18n: { defaultLocale: 'en', locales: { en: 'en', fr: 'fr' } } })]`.
- [x] **Step 3: `wrangler.jsonc`:** `"name": "loomia-site"`, `"compatibility_date": "2026-10-01"`, `"assets": { "directory": "dist", "not_found_handling": "404-page" }`, `"workers_dev": false`, `"preview_urls": false`, `"routes": [{ "pattern": "getloomia.app", "custom_domain": true }]`.
- [x] **Step 4: Write the failing test** `test/site.test.mjs` (reads `dist/`, no dependencies):

```js
const PAGES = ['/', '/privacy', '/support', '/legal', '/fr', '/fr/privacy', '/fr/support', '/fr/legal'];
test('every page is built', ...)            // dist/index.html, dist/privacy.html, dist/fr.html or dist/fr/index.html …
test('no page ships a script', ...)          // no /<script\b/i
test('every page has lang, canonical and hreflang', ...) // <html lang="en|fr">, canonical https://getloomia.app<path>, hreflang en, fr, x-default
test('the language link points at the same page', ...) // the header's alternate link href === altPath(path)
test('nothing reads as MLM', ...)            // none of /recruit|downline|\bPV\b|\bOV\b|elite|essential oil|recrut/i in visible text
test('French uses tu', ...)                  // fr pages: none of /\bvous\b|\bvotre\b|\bvos\b/i
```

- [x] **Step 5: Run it:** `npm run check`. Expected: FAIL, pages missing.
- [x] **Step 6: Implement the layout.** `site.css`: the token table from design-system.md §1 as `--surface-canvas`, `--text-primary`, … under `:root` and `@media (prefers-color-scheme: dark)`; the site scale from the spec (`--hero: clamp(36px, 5vw, 56px)`, `--section-title: 32px`, `--section-gap: clamp(80px, 10vw, 128px)`, `--content: 1200px`, `--reading: 680px`, `--beside: 480px`); `@font-face` for the TTF (`font-weight: 200 800`, `font-display: swap`); buttons `primary/base` with `text/on-primary`, hover `primary/hover`, pill radius; links `primary/text`, underline on hover and `:focus-visible`; a 2px `--state-focus` ring on `:focus-visible`; `@media (prefers-reduced-motion: reduce)` drops transitions. `Mark.astro`: `<svg viewBox="-33.6845 -37.1905 67.369 74.381" aria-hidden="true">` with `<g transform="translate(5.1847 8.6905)" fill="#E8964A">` and the four circles of `icons.sh` `mark()`. `Wordmark.astro`: a link to the language's home, `aria-label="Loomia"`, "l" + Mark sized to the "o" (`height: 0.74em`, the gap 0.046em from `loomia_mark.dart`) + "omia", in `text/primary`. Header: wordmark, the other language's name ("Français" / "English") linking to `altPath`, "Open the app" (`https://app.getloomia.app`). Footer: Privacy, Support, Legal notice, "© 2026 Loomia". `favicon.svg`: the `icons.sh` tile (rx 229 on 1024) with the white mark. `robots.txt`: allow all, `Sitemap: https://getloomia.app/sitemap-index.xml`.
- [x] **Step 7: Commit** on `feature/121-site`: `chore: scaffold the site`. The repo is created with `--add-readme` so `main` exists; nothing is pushed to `main` directly, the whole site arrives in one PR.

### Task 2: Privacy, Support, Legal notice

**Files:**
- Create: `src/layouts/Text.astro`, `src/pages/privacy.md`, `src/pages/support.md`, `src/pages/legal.md`, `src/pages/fr/privacy.md`, `src/pages/fr/support.md`, `src/pages/fr/legal.md`

**Interfaces:**
- Consumes: `Base` (Task 1).
- Produces: `Text` layout, frontmatter `title`, `description`, `lang`, `updated` (ISO date, shown under the title).

- [x] **Step 1: Run** `npm run check`. Expected: FAIL only on the four home paths and the MLM/tu tests that need them.
- [x] **Step 2: `Text.astro`:** the reading column (`--reading`), title, "Last updated" / « Mis à jour le » with `updated`, the Markdown body.
- [x] **Step 3: Privacy, EN then FR:** every point of the spec's Privacy section, in that order, in plain language: who is responsible, what is stored, people in your contacts, where, processors, outside the EU (Data Privacy Framework / standard contractual clauses), what Loomia never does, legal bases, how long (account lifetime; error reports at most 90 days), deleting the account (Settings → Account → Delete account), rights and the CNIL ([cnil.fr](https://www.cnil.fr/fr/plaintes)), age 18+, changes. `updated: 2026-10-30`.
- [x] **Step 4: Support, EN then FR:** the address as a `mailto:` link, "usually within two days", and the four answers from the spec.
- [x] **Step 5: Legal notice, EN then FR:** publisher and publication director Paul Thevenot, `hello@getloomia.app`; host Cloudflare, Inc., 101 Townsend St, San Francisco, CA 94107, USA.
- [x] **Step 6: Run** `npm run check`. Expected: only the home pages still fail.
- [x] **Step 7: Commit:** `feat: privacy, support and legal pages`.

### Task 3: Screenshots

**Files:**
- Create: `src/assets/shots/{today,today-scrolled,contacts,calendar,month}-{light,dark}.webp`

- [x] **Step 1: Capture** on the booted iPhone 17 simulator, signed in to the demo account (Task 0), web or release build of `main`: each of the five screens of the Figma "Site parts" row, light then dark (`xcrun simctl ui booted appearance light|dark`), `xcrun simctl io booted screenshot <name>.png`.
- [x] **Step 2: Check each image by eye:** no PV/OV, no level name, no real person, status bar time 9:41 (`xcrun simctl status_bar booted override --time 9:41` before capturing).
- [x] **Step 3: Convert:** `cwebp -q 82 -resize 780 0 <name>.png -o src/assets/shots/<name>.webp`. Expected: each under 120 KB.
- [x] **Step 4: Commit:** `feat: app screenshots for the home page`.

### Task 4: Home page

**Files:**
- Create: `src/components/Home.astro`, `src/components/Shot.astro`, `src/pages/index.astro`, `src/pages/fr/index.astro`, `src/pages/404.astro`
- Modify: `src/i18n.ts` (home strings), `test/site.test.mjs`

**Interfaces:**
- Consumes: `Base`, `t(lang)`, the screenshots (Task 3).
- Produces: `<Shot name alt />` rendering `<picture>` with a `(prefers-color-scheme: dark)` source and the light image, in the phone outline.

- [x] **Step 1: Add the failing tests:** `test('every screenshot has a dark version and alt text')` (each `<picture>` has a `source` with `prefers-color-scheme: dark` and its `img` a non-empty `alt`); `test('the app link is everywhere')` (each page links `https://app.getloomia.app`); `test('404 page exists')` (`dist/404.html`).
- [x] **Step 2: Run** `npm run check`. Expected: FAIL on the home paths and the new tests.
- [x] **Step 3: Strings in `i18n.ts`,** English verbatim from the spec (hero, four features, closing line, "Coming soon on iOS and Android"); French written to match, in *tu*: hero « Sache qui recontacter aujourd'hui. » and its sentence from the spec.
- [x] **Step 4: `Home.astro`:** hero (title at `--hero`, sentence, button, `today` shot), four features alternating text (eyebrow, title, sentence, max `--beside`) and shot (`today-scrolled`, `contacts`, `calendar`, `month`) on `surface/sunken` bands, closing line, button, the coming-soon line in `text/muted`. One column under the `tablet` width of the app's breakpoints (600 px), text before shot. `Shot.astro`: Astro's `<Image>` is not needed; plain `<img loading="lazy" width height>` except the hero (`fetchpriority="high"`), a 1px `border/strong` outline, radius 28px, `box-shadow: 0 24px 48px rgb(0 0 0 / 0.12)` (0.4 in dark).
- [x] **Step 5: 404:** both languages on one page, links to `/` and `/fr`.
- [x] **Step 6: Run** `npm run check`. Expected: PASS.
- [x] **Step 7: Look at it:** `npx astro preview`, then headless Chrome screenshots at 1440, 768, 390 and 320 wide, light and dark (`--force-dark-mode` for dark). Expected: matches the Figma frames' structure, no horizontal scroll at 320, focus ring visible when tabbing.
- [x] **Step 8: Commit:** `feat: home page`.

### Task 5: SEO and the share image

**Files:**
- Create: `og.html`, `public/og.png`
- Modify: `src/layouts/Base.astro`, `test/site.test.mjs`

- [x] **Step 1: Failing tests:** `test('every page has a title, a description and Open Graph')` (`<title>` non-empty and unique per page, `meta name="description"`, `og:title`, `og:description`, `og:image` = `https://getloomia.app/og.png`, `og:locale` `en_US` / `fr_FR`); `test('sitemap lists every page')` (`dist/sitemap-0.xml` contains the eight URLs).
- [x] **Step 2: Run** `npm run check`. Expected: FAIL.
- [x] **Step 3: Meta tags in `Base`** from the page's `title` and `description`, titles "Privacy · Loomia" etc., home "Loomia — know who to get back to today".
- [x] **Step 4: Share image:** `og.html` at 1200×630 on `surface/canvas`, wordmark at 96px and the `today-light` shot; `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --screenshot=public/og.png --window-size=1200,630 og.html`. Look at it.
- [x] **Step 5: Run** `npm run check`. Expected: PASS.
- [x] **Step 6: Commit:** `feat: titles, Open Graph and sitemap`.

### Task 6: CI, deploy and the handover

**Files:**
- Create: `.github/workflows/site.yaml`
- Modify: `README.md`; app repo: `tool/brand/icons.sh` header, `lib/core/ui/loomia_mark.dart` doc comment

- [x] **Step 1: `site.yaml`:** on `pull_request` and `push` to `main`; Node from `.nvmrc`, `npm ci`, `npm run check`; on `main` only, `npx --yes wrangler@4.147.0 deploy` with `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`. Actions pinned by commit SHA, as in the app repo.
- [x] **Step 2: Secrets:** `gh secret set CLOUDFLARE_ACCOUNT_ID --repo paulthvt/loomia-site --body f256d5e14b0876297cdd86694f427d7a`; Paul sets `CLOUDFLARE_API_TOKEN` (the existing token's value).
- [x] **Step 3: README:** what the site is, `npm run check`, how deploy works, the by-hand Cloudflare parts (Email Routing, `www` redirect), "copy is in the pages and `src/i18n.ts`; French in *tu*".
- [x] **Step 4: The "change together" list:** in the app repo, add `loomia-site/src/components/Mark.astro` to the `icons.sh` header and the `loomia_mark.dart` doc comment, in a small `docs`/`chore` PR; the Figma Brand note needs the same line (Paul, or Claude Code).
- [ ] **Step 5: PR** `feat: marketing site at getloomia.app` with `Closes paulthvt/loomia#121`; CI green; whole-branch review; merge.
- [ ] **Step 6: Verify the deploy:** `curl -sI https://getloomia.app/privacy` → 200; `/privacy/` and `/privacy.html` → 30x to `/privacy`; `/nope` → 404 with the 404 page; `/fr/support` → 200. From a phone if Netskope holds the new domain.
- [ ] **Step 7: Paul, by hand:** `www` → apex (proxied record + 301 Redirect Rule, path kept); App Store Connect Privacy Policy URL `https://getloomia.app/privacy`, Support URL `https://getloomia.app/support`, Marketing URL `https://getloomia.app`; Play Console privacy policy URL.
- [ ] **Step 8: Follow-up issue** in the app repo: link the privacy policy from the sign-up terms line and Settings (spec → After launch, step 3).
