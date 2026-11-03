# In-app privacy and help links Implementation Plan

**Goal:** Sign-up links the privacy policy; Settings opens the privacy policy and help, in the app's language.

**Architecture:** `siteUri` beside `openExternal` builds the site URL; Register renders one localized sentence with the link as an inline `TextButton`; Settings gains a two-row group above Sign out.

**Spec:** `docs/superpowers/specs/2026-11-03-in-app-privacy-links-design.md`

## Global Constraints

- English only in `app_en.arb`, every key described; `authRegisterTerms` removed from every `.arb`.
- No new dependency; links open with `openExternal`.

### Task 1: `siteUri`

- [x] **Test** `test/core/ui/open_external_test.dart`: `siteUri(Locale('en'), '/privacy')` → `https://getloomia.app/privacy`; `Locale('fr')` → `/fr/privacy`; `Locale('de')` → English; `/support` likewise.
- [x] **Implement** `Uri siteUri(Locale locale, String path)` in `lib/core/ui/open_external.dart`.

### Task 2: Sign-up line

- [x] **Test** in `register_page_test.dart`: the sentence "By creating an account, you accept the privacy policy." is on screen and "privacy policy" is a `TextButton`; "terms" is gone.
- [ ] **Implement:** keys `authRegisterPrivacy` ("By creating an account, you accept the {policy}.") and `authRegisterPrivacyLink`; drop `authRegisterTerms` from every `.arb`; `Text.rich` with a `WidgetSpan` button opening `siteUri(locale, '/privacy')`.

### Task 3: Settings rows

- [x] **Test** in `settings_page_test.dart`: "Privacy policy" and "Help" rows are shown, with the open-in-new icon.
- [ ] **Implement:** keys `settingsPrivacyPolicy`, `settingsHelp`; a `SettingsGroup` above Sign out.

### Task 4: Ship

- [ ] `dart format .`, `flutter analyze`, `flutter test`; PR `Closes #418`.
