# iOS promote — design

Issue: #399, epic #400. No UI.

## Intent

Reaching iOS users is the same deliberate step as on Play: one
`gh workflow run Promote -f tag=<tag> -f track=<track>` moves that release's
build forward on both stores. Today Promote knows Play and the web only;
every release already puts its IPA on TestFlight for internal testers (#397)
with the Play build number.

Success: `track=beta` gets the tag's build to external TestFlight testers;
`track=production` submits it for App Store review, and it goes live by
itself once approved.

Anti-goals: a rebuild at promote time; one store's failure blocking the
other; anything reaching users without that command.

## Approaches

| Approach | Trade-off | |
| --- | --- | --- |
| An `ios` job in `promote.yaml`, beside the Play job, running a new `promote` lane | One command for both stores; jobs fail independently. ~5–10 min of macOS runner per promotion. | **Chosen** |
| A separate "Promote iOS" workflow | Simpler file, but two commands and stores that drift. | |
| App Store Connect automatic distribution to an external group | No code for TestFlight, but every release reaches testers and Beta App Review undecided; production still needs code. | |

## Decisions

| Question | Decision |
| --- | --- |
| Tracks | `alpha` and `beta`: the external TestFlight group **External testers** (created by hand, once). `production`: App Store review. No split between alpha and beta on iOS yet. |
| Finding the build | The TestFlight build of app `app.loomia` with build number = the tag's formula (`year*10000 + month*100 + micro`, as `release.yaml`), version string = the tag without `v`. Missing or still processing: the lane fails with a clear message. |
| TestFlight | `upload_to_testflight(distribute_only: true, app_version:, build_number:, groups: ['External testers'], distribute_external: true, notify_external_testers: true, changelog:)`. The changelog ("What to Test") is the English release notes; Beta App Review requires one. The first build of a version waits for Beta App Review. |
| Production | `deliver` with `app_version` = the tag's version (it renames the version open in App Store Connect, today `1.0`), `build_number`, `skip_binary_upload`, `skip_screenshots` (the Store listing workflow owns them), metadata from `ios/fastlane/metadata/` (so the submitted text is `main`'s), `submit_for_review: true`, `automatic_release: true`, `phased_release: false`, `run_precheck_before_submit: false`, `force: true`, the same review details as `upload_listing`. |
| Submission answers | `submission_information`: `content_rights_contains_third_party_content: false`, `export_compliance_uses_encryption: false` (also `ITSAppUsesNonExemptEncryption = false` in the built `Info.plist`). fastlane 2.241.2 has no advertising-identifier answer (the app uses none); App Privacy already says no tracking. |
| What's New | `release_notes` from `release-notes.json`, whose keys are already `en-US` and `fr-FR`, except on the app's first App Store version, where Apple refuses it. deliver skips them there itself (`is_first_version`); the lane leaves them out too, so the log shows no error. |
| Going live | Automatically once Apple approves, all at once (no phased release). |
| Order with Play | The Play job is untouched. The GitHub release still turns final at Play production; the README says the App Store follows after review, hours to days later. |
| Failure | The `ios` job is independent of the Play job (no `needs`): either can fail alone. Rerunning is safe: TestFlight distribution to a group that has the build is a no-op, and production first checks whether the tag's version is already submitted (waiting for review, in review, or approved) and stops with "Already submitted: <state>", instead of failing on a metadata upload that needs an editable version. |
| Build attach | `deliver` attaches the build only while submitting (`submit_for_review: true`), by `app_version` + `build_number`: the lane passes both from the tag, so a mismatch fails as "Build number: X does not exist". |
| Secrets | The existing `ASC_KEY_*`, `ASC_DEMO_USER`, `ASC_DEMO_PASSWORD`, `ASC_REVIEW_PHONE`. Nothing new. |

## By hand, once

1. App Store Connect → TestFlight → **+** next to External Testing: group
   **External testers**, testers added by email or a public link.
2. App Store Connect → Pricing and Availability: **free**, all territories (#105 adds subscriptions later). A first submission needs it; deliver can't set it.
3. README → Releases: the iOS meaning of each track.

## Not now

Phased release, a separate alpha group, public TestFlight link management,
App Store in-app events, release on a date.
