# Marketing site — design

Issue: #121, epic #117. Figma: [Marketing site — #121](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=480-15628)
on "04 — Screens (Light)": home desktop light and dark, home phone, privacy
desktop, and a "Site parts" row (header, footer, five screenshots). Logo: page
"Brand" (node 476:2).

The mockup fixes structure, copy and colour. Polish (type scale, spacing,
device frames) is done in code and reviewed in the browser, not in Figma:
see "Site look".

## Intent

The App Store listing (#398) needs a privacy policy URL and a support URL, and
Play wants the same. That is the job of this first version: public pages at
`getloomia.app` that describe the app as it is today. The home page is a rough
showcase of what Loomia does, to be refined later; it is not a sales page.

Success: both URLs filled in App Store Connect and Play Console, in English
and French, and a home page Paul is happy to send to someone.

Anti-goals: anything that reads as an MLM or sales tool (no "recruit", rank,
"downline", income claims, rockets, fake counters or testimonials); pages that
describe features or processors that don't exist yet; a site that needs a
server.

## Approaches

| Approach | Trade-off | |
| --- | --- | --- |
| Astro in its own repo, `loomia-site` | One layout for every page, i18n routing and sitemap built in, outputs plain HTML with no JavaScript. Costs Node and npm, contained in that repo. | **Chosen** (#117 decision 4) |
| Hand-written HTML, no build | Least tooling, but header, footer and language switch copied into 8 files and kept in sync by hand. | |
| A route in the Flutter web app | Poorly indexed, slow first load, tied to app releases. | Ruled out |

## Decisions

| Question | Decision |
| --- | --- |
| Pages | Home, Privacy, Support, Legal notice. Each in English (`/`) and French (`/fr/`). |
| Pricing page | Not now. It waits for subscriptions (#105); a price nobody can pay yet would mislead. |
| Terms of service | Not now: #114, with subscriptions. Today the app has no paid part. |
| Publisher | Paul Thevenot, as an individual, until his auto-entrepreneur business is registered. Then the legal notice gains the SIRET and a business address (a domiciliation address, not his home). |
| Contact | `hello@getloomia.app`, forwarded to Paul's Gmail by Cloudflare Email Routing (free). One address for support, privacy requests and the legal notice. |
| URLs | Path URLs, no trailing slash: `/privacy`, `/support`, `/legal`, `/fr/privacy`, … English at the root, French under `/fr`. No language detection or redirect: each page links to its other language. |
| French | Written by hand in the repo, informal register (*tu*). Not through Weblate: four short pages, and the legal text needs care. |
| Look | The app's own: Plus Jakarta Sans, the L1 Ocre pale palette (design-system.md §1), the wordmark and mark from the Brand page. Light and dark from `prefers-color-scheme`, no toggle. |
| Logo files | SVGs in the site repo, drawn from the same geometry as `tool/brand/icons.sh`. The Brand page's "change together" list gains the site. |
| Screenshots | Real app screens with sample data only (the names in the app's previews), never a real contact. Phone frames on mobile, a desktop shot on wide screens. |
| JavaScript | None shipped. Astro's output only. |
| Analytics, cookies | None, so no cookie banner. Cloudflare's own logs are the host's, and the privacy policy says so. |
| Stack | Astro (latest stable, pinned in `package-lock.json`), `@astrojs/sitemap`. No UI framework, no CSS framework: one CSS file with the tokens as custom properties. |
| Hosting | Cloudflare Workers static assets, a Worker named `loomia-site`, custom domain `getloomia.app` in its `wrangler.jsonc` `routes`. |
| Deploy | GitHub Actions on push to `main`: `npm ci`, `npm run build`, `wrangler deploy`. Secrets `CLOUDFLARE_API_TOKEN` (the existing token already covers every zone) and `CLOUDFLARE_ACCOUNT_ID`. PRs build only. |
| `www` | `www.getloomia.app` → `https://getloomia.app`, 301, path kept: a proxied DNS record and a Redirect Rule, set by hand in Cloudflare (README of the site). |
| Repo | `paulthvt/loomia-site`, public, same Conventional Commits and PR template as the app. Issues stay on the app repo's board. |

## Pages

All pages share a header (wordmark linking home, "Open the app" button,
language link "Français" / "English") and a footer (Privacy, Support, Legal
notice, © 2026 Loomia).

### Home

1. **Hero.** Headline and one sentence on who it's for, "Open the app" to
   `https://app.getloomia.app`, and a phone screenshot of Today. Proposed:
   - EN: "Know who to get back to today." / "Loomia keeps your contacts, follow-ups and plans in one calm place, so nobody falls through the cracks."
   - FR: « Sache qui recontacter aujourd'hui. » / « Loomia garde tes contacts, tes relances et tes objectifs au même endroit, pour que personne ne passe entre les mailles. »
2. **Four features**, alternating text and screenshot (copy from the mockup):
   - Today: "Know what to do today" / "The people to get back to, your tasks and today's events, on one screen."
   - Contacts: "See where everyone is" / "Each contact shows their step and what comes next, with your notes and tags."
   - Calendar: "Events, and who was there" / "Plan a workshop, invite people, then note who was there and follow up." ("was there", not "came", as in the app: calendar spec → Wording.)
   - Month plan: "Goals without pressure" / "Pick a few goals for the month and see how it's going, at your own pace."
3. **Closing line** "Start with the people you already know." and the "Open
   the app" button again. "Coming soon on iOS and Android" as plain text until
   the store listings are public; no badges.

French copy is written with the build, in the same register.

### Screenshot content

The mockup's screenshots are the app's own sample data, which includes
"960 PV to go", "Aiming for Elite · OV 6 000" and "Essential oils for sleep".
On the public site those read as MLM: points volume, a rank, and the classic
product. Screenshots on the site show none of that: no PV/OV or other points
units (goals in sales or contacts), no rank names, neutral products and
events ("Product evening", "Spring open house"). They are made from the app
(the previews or the simulator) with that data, not copied from Figma.

### Privacy

Plain language first, legal precision second. It describes the app as built
today (checked against the code on 2026-10-30):

- **Who is responsible:** Paul Thevenot, contact `hello@getloomia.app`.
- **What Loomia stores:** your account (email, first name, optional photo,
  language, time zone, notification settings), and what you enter: contacts
  (names, phone numbers, emails, notes, tags), their history, workflows,
  events and who came, tasks, goals and month plans. Contacts imported from
  the phone are copied only when you pick them.
- **People in your contacts:** you decide what to record about them; Loomia
  stores it on your behalf and shows it to nobody else.
- **Where:** Supabase (database, sign-in, photos), EU region (Ireland;
  project `cskjeqspecsyqioietrj`, West EU, checked with
  `supabase projects list`).
- **Processors:** Supabase (hosting, auth), Sentry (error reports, EU region
  Germany: technical data and your user id, never your contacts or email),
  Google Firebase Cloud Messaging (push: a device token), Cloudflare (hosting
  of the site and the web app, standard request logs), Google and Apple when
  you sign in with them (Apple's private relay address is accepted as is).
- **Outside the EU:** Supabase, Sentry, Cloudflare, Google and Apple are US
  companies, and Cloudflare, Firebase and the sign-in providers may process
  data outside the EU. Transfers rely on the EU–US Data Privacy Framework
  where the provider is certified, and on the European Commission's standard
  contractual clauses otherwise. Name this in the policy (GDPR art. 13(1)(f)).
- **No:** ads, selling or sharing data, analytics, tracking cookies. Only the
  sign-in session is kept on the device (theme, language and onboarding live
  in the account's `user_metadata`, not on the device).
- **Age:** Loomia is a tool for running a business; you must be 18 or over.
- **Legal bases:** the contract (running your account), legitimate interest
  (error reports, security).
- **How long:** while the account exists. Deleting the account (Settings →
  Account → Delete account) removes everything at once, photos included.
  Error reports are deleted after at most 90 days (Sentry keeps 30 on the
  free plan, 90 on paid ones; the policy states the upper bound).
- **Your rights:** access, correction, deletion, portability, objection, by
  email; and the right to complain to the CNIL.
- **Changes:** dated at the top; a significant change is announced in the app.

#114 adds RevenueCat and Paddle when subscriptions exist.

### Support

The contact email, a reply time ("usually within two days"), and short
answers: delete my account, reset my password, notifications don't arrive
(check the phone's settings, then the in-app ones), Sign in with Apple and a
hidden email.

### Legal notice (*mentions légales*)

Publisher: Paul Thevenot, contact `hello@getloomia.app` (SIRET and address
once the business exists). Publication director: the same. Host: Cloudflare,
Inc., 101 Townsend St, San Francisco, CA 94107, USA.

The privacy facts above were checked against the code on 2026-10-30: Sentry
on `ingest.de.sentry.io` without `sendDefaultPii`, user id only
(`lib/main.dart`); only ticked phone contacts are saved
(`import_contacts_page.dart`); `delete-account` empties `avatars/<uid>` before
deleting the user. Re-check them whenever a processor or a stored field
changes.

## Calls made while writing, for review

- Minimum age 18, not France's digital-consent age of 15: it is a business
  tool, and subscriptions will need an adult.
- Sentry retention stated as "at most 90 days", true on any plan.
- No DPO: not required for one person at this scale.
- No SIRET on the legal notice until the business is registered; the notice
  names Paul as an individual meanwhile.

## Site look

The app's tokens (colours, font, radii) are the base. A site needs more scale
than an app screen, so the site adds its own, in its CSS only, never in the
app:

- **Type:** a hero size of 56 px on desktop, scaling down to 36 px on phone
  (`clamp`), and 32 px section titles. The app's ramp stays for body text.
- **Spacing:** 128 px between sections on desktop, 80 px on phone.
- **Widths:** content max 1200 px, reading column 680 px, text beside a
  screenshot 480 px.
- **Screenshots:** a phone outline (thin bezel, the app's radius) with a soft
  shadow, light and dark versions swapped with `prefers-color-scheme`.
- **Links:** text links in the brand's text colour, underlined on hover and
  focus, visible focus ring everywhere.
- **Motion:** none beyond hover; respects `prefers-reduced-motion` anyway.

These are judged in the browser on the first build, not drawn back into
Figma.

## SEO

Per page: `<title>`, meta description, canonical URL, `hreflang` pair
(en, fr, and `x-default` → English), Open Graph title, description and one
shared image (wordmark and a Today screenshot, 1200×630), sitemap via
`@astrojs/sitemap`, `robots.txt` allowing everything. The web app keeps its
own `noindex`.

## After launch (by hand)

1. Cloudflare Email Routing on `getloomia.app`: `hello@` → Paul's Gmail.
2. App Store Connect: Privacy Policy URL `https://getloomia.app/privacy`,
   Support URL `https://getloomia.app/support`, Marketing URL
   `https://getloomia.app`. Play Console: the privacy policy URL.
3. Link the privacy policy from the app: the sign-up terms line and Settings.
   That is an app change, a separate issue.

## Not now

Pricing (#105), terms of service (#114), store badges, a blog, a newsletter,
a contact form, analytics, a dark-mode toggle, more languages.

## To mock

For Claude Code, in Figma file `spz2vsSK8gbt1Ok2rW1sdQ`, page
"04 — Screens (Light)", a new section "Marketing site — #121":

1. **Home, desktop (1440 wide), light:** header, hero with the phone
   screenshot of Today, four features alternating text and screenshot, closing
   line, footer. Copy from "Pages → Home" above.
2. **Home, desktop, dark:** the same frame in the Dark mode of the colour
   variables.
3. **Home, phone (390 wide), light:** one column; header with the wordmark and
   a compact "Open the app".
4. **Privacy, desktop, light:** a long text page (headings, paragraphs, a
   list), 680 px reading column, to set the type for every text page.

Rules: use the `Logo/Wordmark` and `Logo/Mark` components, the colour and type
variables (no new hex values), and existing Today, Contacts, Calendar and month
plan frames as screenshots. No store badges, no counters, no testimonials. Say
what you couldn't do with the existing variables.
