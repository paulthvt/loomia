# Auth emails from getloomia.app — design

Issue: #119 (web epic #117). No new app UI, no Figma section.

## Intent

Sign-up confirmations and password resets come from `hello@getloomia.app`,
land in the inbox, keep arriving when several people sign up in the same hour,
and read like Loomia: Loomia's wording and look, in English or French.

Today Supabase's built-in sender allows a few emails an hour for the whole
project, sends from a Supabase address, and only in English.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Provider | Brevo, SMTP relay `smtp-relay.brevo.com:587` | French company, EU hosting, fits the privacy policy; free plan is 300 emails a day. |
| Credentials | `user = "env(BREVO_SMTP_LOGIN)"`, `pass = "env(BREVO_SMTP_KEY)"` in `[auth.email.smtp]`, supplied at `supabase config push` like the Google/Apple secrets | Nothing secret in the repo; the SMTP key is not the Brevo API key. |
| Sender | `admin_email = "hello@getloomia.app"`, `sender_name = "Loomia"` | Supabase has no reply-to; replies reach the existing Cloudflare Email Routing inbox. |
| Rate limit | `[auth.rate_limit] email_sent = 50` (per hour) | Was 2, which only applies once SMTP is on. 50 an hour stays inside Brevo's daily 300 for a normal day. |
| DNS | Brevo's "Authenticate your domain" records (Brevo code TXT, DKIM, DMARC `p=none` to start), added by hand in Cloudflare. If Brevo lists an SPF entry, it is merged into the existing SPF record, never added as a second one. | A domain has one SPF record; the current one is Cloudflare Email Routing's. |
| Which emails | Confirm sign-up (`confirmation`), reset password (`recovery`), and the "your password was changed" notice (`notification.password_changed`, turned on) | These are the ones the app triggers. No email-change, invite or magic-link flow exists in the app, so those keep Supabase's defaults. |
| Language | The template picks French when `.Data.locale` is `fr`, else when `.Data.email_locale` is `fr`, else English. Subjects use the same condition. | `locale` is only set once someone picks a language in Settings. |
| `email_locale` | `signUp` adds `email_locale: <app's resolved language code>` to its `data` | Saved at sign-up, so the confirmation and later resets know the language. A separate key, so "follow the system" (`locale` null) stays untouched. Resend and reset can't write metadata (signed out); they reuse what sign-up saved. |
| Where the copy lives | `supabase/templates/*.html`, English and French side by side in each file. French in *tu*. | Weblate only handles ARB. Documented exception to "other languages come from Weblate" in README → *Translations*; a third language means editing the templates. |
| Look | One HTML table layout with inline styles: "Loomia" wordmark as text, one short paragraph, one button in brand `primary` `#A75C15` with white text, the plain link underneath, a footer with getloomia.app. No images. | Mail clients ignore stylesheets; no image means nothing gets blocked. |
| Privacy policy | One line on `loomia-site` naming Brevo (Sendinblue SAS, France) as the email processor, EN and FR, separate PR | Required once Brevo handles addresses. |

## Wording

- **Confirm** — subject "Confirm your email for Loomia" / "Confirme ton email
  pour Loomia". "Hi {first name}, tap the button to confirm your email and
  start using Loomia." Button "Confirm my email" / "Confirmer mon email".
  "If you didn't create an account, ignore this email."
- **Reset** — subject "Reset your Loomia password" / "Réinitialise ton mot de
  passe Loomia". Button "Choose a new password" / "Choisir un nouveau mot de
  passe". "If you didn't ask for this, ignore this email: your password stays
  the same."
- **Password changed** — subject "Your Loomia password was changed" / "Ton mot
  de passe Loomia a été modifié". "If it wasn't you, reset your password now
  and write to hello@getloomia.app."

The greeting falls back to "Hi," / "Bonjour," when `first_name` is empty.

## Tests

- Dart unit test `test/supabase/email_templates_test.dart`: each template in
  `config.toml` exists, has an English and a French branch, contains
  `{{ .ConfirmationURL }}` where it needs one, and the French text has no
  *vous*.
- `AuthRepository.signUp` sends `email_locale` (existing repository test
  pattern, fake client).
- By hand, locally: `supabase start`, sign up with no locale, `en` and `fr`,
  read the three emails in Mailpit, including the no-name greeting and a
  missing `locale` key (Go templates must not error on it).
- After `config push`: one real sign-up and one reset to a Gmail and an Outlook
  address; check SPF/DKIM/DMARC pass in the headers and the mail isn't in spam.

## By hand, Paul

1. Brevo account, then "Authenticate your domain" for `getloomia.app`; add its
   records in Cloudflare DNS.
2. Generate an SMTP key; note the SMTP login.
3. After merge: `BREVO_SMTP_LOGIN=... BREVO_SMTP_KEY=...` alongside the
   existing secrets on `supabase config push` (README updated with the line).

## Not now

An 8-digit code in the emails for mail scanners that open links before the
user (Outlook Safe Links), the email-change flow, more languages, Brevo
tracking (opens/clicks stay off).
