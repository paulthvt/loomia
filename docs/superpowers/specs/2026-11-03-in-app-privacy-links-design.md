# In-app privacy and help links — design

Issue: #418. Small change: no new UI pattern, no Figma section.

## Intent

From inside the app, someone can read the privacy policy and reach help, in
the app's language: at sign-up and any time in Settings. Apple and Google
expect the privacy policy to be reachable in the app, not only on the store
page.

## Approaches

One sensible way: reuse `openExternal` (`lib/core/ui/open_external.dart`) to
open the site's pages in the browser, and the existing `ListTile` rows in
Settings. An in-app web view would need a new dependency for two static pages;
copying the policy into the app would mean two copies to keep in step.

## Decisions

| Question | Decision |
| --- | --- |
| Sign-up line | "By creating an account, you accept the privacy policy." The terms are dropped until #114 writes them. "privacy policy" is a link. |
| How the link sits in the sentence | One translatable sentence with a placeholder, `authRegisterPrivacy` "By creating an account, you accept the {policy}.", and `authRegisterPrivacyLink` "privacy policy". The placeholder is drawn as an inline text button (`WidgetSpan`), so it is a real button for screen readers and the keyboard. |
| Old key | `authRegisterTerms` is removed from every `.arb` (its meaning changed). French shows the English line until Weblate's next pull request. |
| Settings | A group above Sign out with two rows: **Privacy policy** (`Icons.privacy_tip_outlined`) and **Help** (`Icons.help_outline_rounded`), each with `Icons.open_in_new_rounded` trailing, since they leave the app. Keys `settingsPrivacyPolicy`, `settingsHelp`. |
| URLs | `https://getloomia.app/privacy` and `/support`; `/fr/privacy` and `/fr/support` when the app's resolved language is French. One helper, `siteUri(Locale locale, String path)`, beside `openExternal`. |
| Opening | `openExternal` (external browser; a SnackBar if nothing opens it). |

## Tests

- Unit: `siteUri` gives the English and French URLs for both pages, and
  English for any other language.
- Widget: Register shows the sentence with the link button; Settings shows
  both rows. No golden changes (neither screen has a preview).

## Not now

Terms of service (#114), an in-app web view, a "Contact us" form.
