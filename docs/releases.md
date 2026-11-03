# Releases: who gets what, and how Loomia goes public

The big picture of the release cycle. The commands, secrets and one-time setup
are in README.md → Releases; this page says who each channel is for, what each
step changes on which store, and the road to a public launch.

## The cycle

1. **Merge `feat`, `fix` or `perf` PRs into `main`.** yeet keeps a release PR
   ("chore: release YYYY.MM.N") up to date. `ci`, `docs`, `chore`, `test` and
   `refactor` alone cut no release.
2. **Merge the release PR.** It tags `vYYYY.MM.N` and the Release workflow
   ships that one build to internal testers everywhere (below).
3. **Promote.** `gh workflow run Promote -f tag=<tag> -f track=<track>` moves
   those same builds to a wider audience. It never rebuilds.

## What a release changes

Merging the release PR (`.github/workflows/release.yaml`):

| Where | What changes | Who sees it |
| --- | --- | --- |
| Supabase (hosted) | Migrations pushed (`supabase db push`), before any build | Everyone, at once: the released apps keep working (migration guard) |
| GitHub | Tag and a **pre-release** with the APK, the web zip, `release-notes.json` (EN/FR, from Gemini) and `store-screenshots.zip` | — |
| Google Play | AAB uploaded to **internal testing**, with What's new | Internal testers |
| Web (Cloudflare) | A **preview version** at `internal-loomia.<account>.workers.dev`, not live | Whoever has the URL |
| App Store Connect | IPA uploaded to **TestFlight**, internal testers, "What to Test" in English | Your App Store Connect team |

Not touched by a release: the live web app, the Play and App Store listings,
any public or tester track beyond internal.

## Channels

| Track | Play | iOS | Web | For whom | Review |
| --- | --- | --- | --- | --- | --- |
| internal (every release) | Internal testing (up to 100 emails) | TestFlight, internal (App Store Connect team) | Preview URL | Paul and family | None |
| `alpha` | Closed testing "Alpha" (email list) | TestFlight group **External testers** (emails or public link) | — | Invited testers | Google per change; Apple on a version's first build (Beta App Review) |
| `beta` | Open testing (anyone can join from the store page) | **External testers** (same as alpha) | — | A public beta, not used yet | Same |
| `production` | Public on Google Play | Submitted for App Store review, public by itself once approved | Live at `app.getloomia.app` | Everyone | Google and Apple: hours to a few days |
| `web` | — | — | Live at `app.getloomia.app` | Web users | None |

`production` also turns the GitHub pre-release into the latest release. The
Play and iOS jobs are independent: one failing leaves the other alone, and a
failed job can be rerun alone.

## What a promote changes

| Track | Play | App Store Connect | Web |
| --- | --- | --- | --- |
| `alpha`, `beta` | The internal build moves to the track, What's new from `release-notes.json` | The TestFlight build is added to **External testers**, "What to Test" from the English notes | — |
| `production` | Public rollout, 100% | The open App Store version is renamed to the tag, the build attached with the listing text from `main` and What's New, submitted; released automatically after approval, no phasing | The tag's preview becomes live |
| `web` | — | — | The tag's preview becomes live |

The store listings themselves change only when asked:

- **App Store:** text and screenshots from `ios/fastlane/metadata/` and a
  release's `store-screenshots.zip`, with `gh workflow run "Store listing" -f
  tag=<tag>` (README → iOS → Store listing). `production` also sends the text.
  App Privacy is answered by hand.
- **Play:** the listing (text, screenshots, data safety, content rating) is
  edited by hand in Play Console. Promote sends only What's new.

## Going public

1. **Testing.** Releases go to `alpha` on both stores. Testers are added in
   Play Console (closed testing email list) and in TestFlight (External
   testers: emails or the public link).
2. **Play's personal-account rule:** 12 testers opted in to closed testing for
   14 days in a row. Then Play Console → **Apply for production**: a short
   questionnaire about the test; Google answers in about a week. Apple has no
   such rule.
3. **Before launch, outside the stores:** the auto-entrepreneur business
   (then the site's legal notice, the Play payments profile and developer
   details), the trademark (#415), the in-app privacy and support links
   (#418), subscriptions (#105) if paid from day one.
4. **Launch:** `track=production`. Play and the web are public the same day;
   iOS is public once Apple approves, usually within a day or two.

After launch the cycle is the same: release, `alpha` for testers, then
`production` when a build has proven itself.

## Status

Updated by hand. As of 2026-11-03:

- **v2026.11.4** on `alpha`: Play closed testing and TestFlight External
  testers (waiting for Beta App Review). Google approved the app's setup on
  2026-11-03.
- Production: inactive on Play; App Store version open, never submitted.
- Web live: v2026.11.3 (`track=web`).
- Next: testers on both stores, then the 14 days on Play.
