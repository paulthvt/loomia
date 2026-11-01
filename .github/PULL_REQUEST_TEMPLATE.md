<!--
PR title must be a Conventional Commit — it becomes the squash commit subject
and drives the changelog. e.g. feat(contacts): add follow-up reminder
Types: feat fix docs style refactor perf test build ci chore revert
-->

## Ticket

<!--
Required. The issue tracked on the board:
https://github.com/users/paulthvt/projects/2
Use "Closes #123" so merging moves the card to Done. Several: one per line.
-->

Closes #

## What & why

<!-- What changed, and the reason. -->

## Screenshots

<!-- Any visual change: before/after. Mobile + desktop layout if both are affected. -->

## Database

<!--
Delete if there is no migration. Otherwise:
- Pushed at merge by the Release workflow; Edge Function to deploy by hand: none / which
- Released app: keeps working / breaks because … (then split the PR: add the
  new beside the old now, remove the old once users have updated; only that
  second PR gets the `breaking-migration` label)
-->

## Checklist

- [ ] `dart format .`, `flutter analyze`, `flutter test` all pass locally
- [ ] Theme values come from `colorScheme` / `AppSpacing` / `AppRadii` — nothing hard-coded
- [ ] No new dependency, or the reason is in the `pubspec.yaml` comment next to it
- [ ] Goldens regenerated on Linux if they changed (see `.github/workflows/ci.yaml`)
- [ ] Linked issue exists on the board and the branch is named `<type>/<issue>-<slug>`
