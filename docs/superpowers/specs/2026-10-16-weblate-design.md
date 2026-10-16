# Translations through Weblate

Issue: #344. Instance: https://weblate.thevenot.me/ (Weblate 2026.10.1).

## Why

Today `tool/translate.dart` sends new or changed English to Gemini, and the
*l10n sync* workflow opens `chore/l10n-sync` with the result. Review means
reading a diff. Moving to the self-hosted Weblate gives:

- a review UI with suggestions, history, translation memory and checks;
- room for human translators and reviewers later;
- glossary, per-language rules and the rest without growing our own tooling.
  We maintain the instance, not a translation pipeline.

Weblate owns the translations. English stays the source of truth in
`lib/l10n/app_en.arb`, edited only in the repo. Translations still reach the
app as a pull request that passes the same CI.

## Weblate

Project `loomia`, inside a workspace (the GitHub App requires one).

Component `app`:

| Setting | Value |
| --- | --- |
| Version control | GitHub App (registered from Manage → Code-hosting connections) |
| Repository / branch | `https://github.com/paulthvt/loomia.git`, `main` |
| Push branch | `weblate/l10n` (pull request mode) |
| Merge style | merge |
| File format | ARB file |
| File mask | `lib/l10n/app_*.arb` |
| Monolingual base | `lib/l10n/app_en.arb` |
| Template for new translations | empty |
| Edit base file | off |
| Commit message | `chore(l10n): translate {{ language_name }}` |

The GitHub App delivers push events, so there is no manual webhook. It is
installed on `paulthvt/loomia` only.

Add-ons:

- **Automatic translation** with the Gemini engine, on new and changed strings,
  state *Needs editing*: every machine string sits in a review queue.
- **Cleanup translation files**: keys removed from English disappear from every
  language.
- **Customize JSON output**: 2-space indent, matching the current files, so diffs
  stay small.

Translation rules, moved from the prompt in `tool/translate.dart`, go into the
Gemini engine's prompt/context field when the instance exposes one, otherwise
into the project's translation instructions:

- informal register; French *tu, ton, ta, tes*, informal imperatives, never
  *vous, votre, vos*;
- calm, plain, warm; never salesy, no "recruit" language;
- keep placeholders and ICU plural/select syntax;
- natural phrasing over word for word, neutral wording over gendered.

Starter glossary: Loomia (untranslatable), follow-up, check-in, contact.

Each `@key` description in `app_en.arb` is shown to translators, so the
"every key has a description" rule stays.

The existing `app_fr.arb` is imported on component creation: no translation is
lost.

To check on the live instance during setup: whether *Needs editing* strings are
written to the ARB file. If not, a language shows English for a string until it
is approved; acceptable, gen-l10n falls back to English and the tests allow a
lagging language.

## Repo

Deleted:

- `tool/translate.dart`, `test/tool/translate_test.dart`
- `lib/l10n/translation_sources.json`
- `.github/workflows/l10n-sync.yaml`

Kept: `tool/gemini.dart` and the `GEMINI_API_KEY` secret (release notes),
`tool/push_strings.dart`, `test/l10n/*`, `test/tool/push_strings_test.dart`.

New `.github/workflows/weblate-pr.yaml`, on `pull_request` (opened,
synchronize) for head branch `weblate/l10n`:

1. Skip when the head commit is its own (no loop).
2. Token from the `yeet` GitHub App (`vars.YEET_APP_ID`,
   `secrets.YEET_APP_PRIVATE_KEY`, as in `release.yaml`): commits pushed with
   `GITHUB_TOKEN` do not trigger CI, and the `main` ruleset requires four checks
   on the head commit.
3. `dart run tool/push_strings.dart`; commit any change to the branch as
   `chore(l10n): push strings`.
4. `gh pr edit --title "chore(l10n): sync translations" --add-label l10n`: the
   Weblate default title fails *Conventional PR title*.

`ci.yaml` is unchanged.

### Risk and fallback

Weblate does not document what it does when its push branch gains a commit it
did not make: its next push may be refused or overwrite ours. Probe before
writing the workflow: let Weblate push, add a commit to `weblate/l10n`,
translate another string, watch the next push.

If it breaks: Weblate's pull request leaves the push files alone and a workflow
on push to `main` (paths `lib/l10n/app_*.arb`) regenerates them into a
`chore/push-strings` pull request, the pattern l10n sync uses today. Switching
needs the owner's OK.

## Docs

- README → *Translations*: rewritten for Weblate (link, adding a string,
  reviewing, glossary, adding a language in Weblate, the `weblate/l10n` pull
  request and its workflow, the register rule now in Weblate with the test as
  backstop, `GEMINI_API_KEY` only for release notes).
- `AGENTS.md` *Copy*: other languages come from Weblate through the
  `weblate/l10n` pull request.
- `.kiro/steering/l10n.md`: same; drop `tool/translate.dart` from
  `fileMatchPattern` and the `translation_sources.json` line.
- Past specs and plans under `docs/superpowers/` are history and stay.

## Rollout

1. Owner: create the workspace, register the GitHub App on `paulthvt/loomia`,
   write the API key to `~/.config/weblate` (wlc ini format; never pasted in
   chat), merge or close any open `chore/l10n-sync` pull request.
2. Project, component, add-ons, glossary and instructions created through the
   Weblate API; check the *Needs editing* behaviour.
3. Probe the extra-commit behaviour (above).
4. Repo pull request on `chore/344-weblate`: deletions, workflow, docs.
   `dart format .`, `flutter analyze`, `flutter test` green; `Closes #344`.
5. After merge, end to end: change one English string; expect Weblate to pick
   it up, Gemini to suggest, the pull request to open, push strings to be
   committed, the four required checks to pass.

No database change: no migration, no `supabase db push`.
