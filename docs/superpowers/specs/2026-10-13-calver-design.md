# Calendar versioning — design

Issue: #306. No Figma section: no UI. Replaces release-please (README.md →
Releases) by [yeet](https://github.com/monkescience/yeet); the rest of the
release flow (internal first, `promote.yaml` ships the same build further)
stays.

## Intent

Semver tells an API consumer what may break. Loomia has none: its users only
need to know how recent their build is, and so do we when a crash comes in.
A date says that; `0.11.0` does not. The switch happens before the first iOS
upload so the App Store never sees a `0.x` version.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Format | `YYYY.MM.MICRO`: `2026.10.1`, `2026.10.2`, then `2026.11.1`. | Year and month say how old a build is; MICRO counts releases in the month and starts at 1 (yeet's rule). Unpadded: `2026.01.1` is not valid semver, which `pubspec.yaml` requires, and Dart would print it `2026.1.1`. Full year, so the first number is never mistaken for a major. |
| Date | UTC, at the moment yeet computes the version. | Same answer locally (`--dry-run`) and in CI. |
| Tool | yeet, run from its Docker image pinned by digest. | Supports CalVer, keeps the Release PR flow release-please gave us. release-please is semver only ([#1848](https://github.com/googleapis/release-please/issues/1848)), and pinning a version by hand needs a commit per release. A home-made workflow would mean owning changelog code. |
| What releases | `feat`, `fix`, `perf` commits since the last tag, as today. Commit types no longer size the bump; `!` / `BREAKING CHANGE` only adds the changelog section. | yeet's defaults. |
| Release PR month | A PR opened in October and merged in November with no push in between tags `2026.10.x`. Accepted. | yeet recomputes on every push to `main`; the tag still sorts above every earlier one, which is all the stores check. |
| First version | Tag `v2026.10.0` (lightweight, no GitHub release) on the `0.11.0` commit, then the first yeet release is `2026.10.1` (or `2026.11.1`). | yeet skips tags it cannot parse as CalVer (`0.11.0`, `v0.1.x`); with no CalVer tag its first changelog would cover the whole history. The bootstrap tag gives it a starting point. It is never promoted. |
| Old tags | Kept. | History, and `0.x` releases stay promotable on Play while they are the latest there. |
| `pubspec.yaml` | `version: 2026.10.0 # x-yeet-version`, no `+build`; yeet rewrites it in each Release PR. | Local builds and `flutter run` show the right version. The build number is CI's (`--build-number`); yeet's marker replaces the whole value, a `+N` included. |
| Build number | Unchanged formula: `major*10000 + minor*100 + patch` → `2026.10.1` is `20261001`. | Month ≤ 12 removes the "minor passes 99" ceiling; the remaining one is 100 releases a month. Same number on Play (`versionCode`, max 2 100 000 000) and iOS (`CFBundleVersion`), so a promote step finds the same build on both stores. |
| `CHANGELOG.md` | Kept; yeet appends to it. Section headings unchanged (`✨ Features`, `🐛 Bug Fixes`, …) through `changelog.sections`. | Existing entries are not rewritten, and `tool/release_notes.dart` matches headings by suffix. |
| Tag prefix | `v`: tags are `v2026.10.1`, the version (pubspec, PR title) `2026.10.1`. | yeet requires a non-empty `tag_prefix`. It also keeps CalVer tags apart from the `0.x` ones, and `promote.yaml` already strips a `v`. |
| Token | A GitHub App (`YEET_APP_ID` variable, `YEET_APP_PRIVATE_KEY` secret), installed on this repository only, Contents and Pull requests read/write. | yeet force-pushes its `yeet/release-*` branch. An App token also triggers CI on the Release PR, which the `GITHUB_TOKEN` fallback never did; the `RELEASE_PLEASE_TOKEN` comment goes. |
| Release PR title | `chore: release 2026.10.1` (`release.pr_title` and `commit_subject`). | The App token makes CI run on the Release PR, so it must pass the Conventional PR title check; a `chore` subject never triggers a release of its own. |
| Detecting a release | The CalVer tags before yeet, compared with the tags after it (`git fetch --tags`). A new one is the release; none, the build job is skipped. The build job checks out that tag. | yeet has no action outputs. `git tag --points-at HEAD` would miss a release: when a push lands right after the Release PR merge, yeet skips the older run and tags the merge commit from the newer one, where `HEAD` is the later commit. A re-run with nothing new builds nothing. |
| Prerelease | Unchanged: `release.yaml` still marks the GitHub release a pre-release, `promote.yaml` makes it final. | yeet's prerelease channels are semver only, and not needed. |
| Telemetry | Off: `telemetry: enabled: false` in `.yeet.yaml`, and `DO_NOT_TRACK=1` on the job. | Anonymous, but on by default and adds nothing for us. |
| Breaking-change config | `bump-minor-pre-major` and friends dropped. | Meaningless with CalVer. |

## 1. iOS

Nothing iOS-specific to build in #306; this records why the format holds when
the TestFlight job lands.

- `CFBundleShortVersionString` = `$(FLUTTER_BUILD_NAME)` (`ios/Runner/Info.plist`):
  at most three non-negative integers separated by dots. `2026.10.1` fits.
  Each App Store version must be higher than the last: dates only go up.
- `CFBundleVersion` = `$(FLUTTER_BUILD_NUMBER)`: must increase within a
  version. `20261001` does, and is the same number as Play's.
- A rejected review is resubmitted as a new release: MICRO + 1.
- The iOS job builds with `--build-number="$CODE"` like Android; the version
  name comes from `pubspec.yaml` at the tag.

## 2. Play

- The next `versionCode` jumps from `1100` (`0.11.0`) to `2026100x`. Play only
  needs it to increase. One-way: no semver release can follow.
- `promote.yaml` keeps deriving the code from the tag; only its examples
  change (`-f tag=v2026.10.1`).

## 3. Repository changes

- `.yeet.yaml` (new): one target `loomia`, `path: .`, `tag_prefix: v`,
  `versioning: calver`, `calver.format: YYYY.MM.MICRO`, `timezone: UTC`,
  `version_files: [pubspec.yaml]`, `changelog.include` and
  `changelog.sections` carrying today's nine sections and headings, telemetry
  off.
- `release-please-config.json`, `.release-please-manifest.json`: deleted.
- `.github/workflows/release.yaml`:
  - the `release-please` job becomes `yeet`: full-history checkout, App
    token, the pinned image running `yeet release`, the tags compared before
    and after, `tag` as a job output;
  - `artifacts` runs on `needs.yeet.outputs.tag != ''`, checks out that tag
    and reads it from there;
  - the builds keep `--build-number` only: at the tag, `pubspec.yaml`
    already holds the version yeet wrote in the Release PR;
  - the header comment describes the yeet flow.
- `.github/workflows/promote.yaml`: input description and usage example.
- `.github/workflows/ci.yaml`: the PR-title comment names yeet.
- `tool/release_notes.dart`: list items are `- ` (yeet) as well as `* `
  (older releases, re-run by hand).
- `README.md` → Releases: yeet, the App setup, CalVer, the build-number line,
  `2026.10.1` in the examples.

## 4. Rollout

1. Create the GitHub App, set `YEET_APP_ID` / `YEET_APP_PRIVATE_KEY`.
2. Push the bootstrap tag: `git tag v2026.10.0 0.11.0^{} && git push origin
   v2026.10.0`. Before the #306 merge, or yeet starts from no tag.
3. Locally: `yeet release --dry-run` on `main`. It must show the
   `2026.10.0` baseline, propose `2026.MM.1` and only the commits after
   `0.11.0`.
4. Merge the #306 PR. Close any open release-please PR first (yeet ignores
   its branch).
5. The first yeet Release PR appears on the next `feat`/`fix`/`perf` merge;
   merging it ships `2026.MM.1` to Play internal and the web preview.

## 5. Testing

- Unit: `release_notes_test.dart` gains a yeet-shaped body (`- ` items,
  `([abc1234](…))` links, a `⚠ BREAKING CHANGES` section left out).
- Workflow: step 3 of Rollout, then the first real release checked end to
  end: tag, pre-release with APK, web zip and notes, `versionCode` on Play
  internal, `promote.yaml` to alpha finding it.
- No golden or widget change.
