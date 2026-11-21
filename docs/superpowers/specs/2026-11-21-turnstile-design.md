# Turnstile on email auth, then open sign-ups — design

Issue: #529. No new UI pattern (invisible check, no Figma section).

## Intent

Let people create their own accounts on web, Android and iOS without the bot
sign-ups that closed them (#479). Each bot sign-up now also sends a real email
through Brevo (#119), which spends the daily quota and hurts the reputation of
`getloomia.app`. Supabase's own captcha check, with Cloudflare Turnstile, stops
them on the server, whatever client calls the API.

Goals: sign-ups open; no visible captcha for a normal person; nothing breaks
for Google and Apple sign-in. Non-goals: protecting anything after sign-in.
Anti-goal: a captcha that sometimes blocks a real person from signing in with
no way out.

## Approaches

| Approach | Trade-off | |
| --- | --- | --- |
| `cloudflare_turnstile` package | Least code, covers web too; but it depends on `flutter_inappwebview`, whose iOS part is CocoaPods-only. The iOS build is SPM-only, so it would bring CocoaPods back. | Rejected |
| Our own invisible Turnstile page in `webview_flutter`; Turnstile's script on the web | About 150 lines of our own; `webview_flutter` is Flutter's plugin and supports SPM. | **Chosen** |
| Visible widget in a sheet | More reliable where invisible fails, but a new UI pattern and a step for everyone. | Fallback only |

## Spike result (spike/529-turnstile, not merged)

On a real iPhone and Android phone, the page loaded by `loadHtmlString` with
`baseUrl: https://getloomia.app` got a token from the invisible test key in
3–4 s; the failing key reported `600010`, then Turnstile retried on its own
every ~12 s. No `Podfile` appeared; iOS built through SPM.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Which actions | Every call Supabase checks: `signUp`, `signInWithPassword`, `resetPasswordForEmail`, `resend`, each with `captchaToken`. Google and Apple untouched. | Supabase requires the token on all of them once on. |
| Where the token is fetched | `lib/features/auth/data/captcha.dart`: a `Captcha` with `Future<String> token()`, behind `captchaProvider`. `AuthRepository` takes the token as a parameter; pages read it from the provider and pass it. | Widgets never call Turnstile; tests override one provider. |
| Mobile | A `WebViewController` loads the page below with `loadHtmlString(baseUrl: 'https://getloomia.app')`; the token comes back through a JavaScript channel. The web view must be in the tree: `CaptchaHost`, a 1×1 `ExcludeSemantics` widget, sits in each of the four auth pages. | Proved by the spike; no hosted page to keep. |
| Web | Turnstile's `api.js` injected into the app's document, an invisible widget rendered into a hidden `div`, through `package:web` and `dart:js_interop`. One `Captcha` per platform by conditional import (`captcha_web.dart` / `captcha_io.dart`). | The page is already a browser; no web view needed. `web` becomes a direct dependency (already in the lock). |
| The page | `size: 'invisible'` widget key, `retry: 'never'`, `refresh-expired: 'manual'`, callbacks for token, error, timeout, unsupported. | Turnstile's own retry loops forever on a failure; we decide. |
| Speed | The page starts fetching a token when an auth page opens. Submitting waits for that token (the button is already busy). A token is used once; after use, or after 4 min (tokens expire at 5), the next one is fetched. | Saves the 3–4 s on submit. |
| Failure | No token within 15 s, or a Turnstile error: one silent retry, then `AuthFailure.captcha`, "We couldn't check this device. Try again, or sign in with Google or Apple." Supabase's "captcha verification process failed" maps to the same. | The anti-goal: the person always has a way out. |
| Keys | The site key is public: `SupabaseConfig.turnstileSiteKey`, committed. The secret is `env(TURNSTILE_SECRET_KEY)` in `[auth.captcha]`, supplied at `config push` like the others. | Same rule as every secret. |
| Widget hostnames (Cloudflare) | `getloomia.app`, `app.getloomia.app`, the web preview host, `localhost`. | Every place the app or its page runs; `localhost` for `flutter run -d chrome`. |
| Debug builds | Use the real site key. | They talk to the hosted project, which checks with the real secret. |
| Rollout | PR 1: the app sends a token, `[auth.captcha]` stays off (Supabase ignores the token). Release, Paul updates his phones and his wife's, check no build is in Apple review. PR 2: `[auth.captcha] enabled = true` and `[auth] enable_signup = true`, then `config push`. | A build without the token can no longer sign in with email once it is on. No outside testers yet. |
| Before PR 2 | Check the real site key with `loadHtmlString` on a phone (the test key accepts any hostname). If Cloudflare rejects the `baseUrl` origin, host the same page at `getloomia.app/captcha` in `loomia-site` and load it by URL instead. | The one thing the spike couldn't prove. |
| Privacy policy | `loomia-site`, EN and FR: Cloudflare's line gains "and checks that sign-ups come from a person (Turnstile)", with a link to Cloudflare's [Turnstile Privacy Addendum](https://www.cloudflare.com/turnstile-privacy-policy/). Live before PR 1's release. | Cloudflare requires the addendum reference for invisible mode; the check runs on devices from PR 1 on, even while Supabase ignores it. |
| Pre-clearance ("Skip future security rule challenges") | Off. | It sets a `cf_clearance` cookie to skip Cloudflare WAF challenges; the zone has none for app users, and the policy promises no cookies beyond the session. |

## Tests

- Unit (`test/features/auth/data/captcha_test.dart`), with a fake page: a
  token is reused only once; one older than 4 min is replaced; an error is
  retried once, then `AuthFailure.captcha`; no answer in 15 s counts as an
  error.
- Widget: each of the four pages passes the fake token to the repository, and
  shows the `captcha` copy when the token fails. `FakeAuthRepository` records
  the token.
- `authFailureFrom` maps Supabase's captcha error to `AuthFailure.captcha`.
- By hand, before PR 2: sign up, sign in, reset and resend on iPhone, Android
  and the web with the real key, captcha still off; then again after
  `config push`.

## By hand, Paul

1. Cloudflare → Turnstile → Add widget "Loomia", mode **Invisible**, the
   hostnames above. Send the site key; keep the secret key.
2. After PR 2: `TURNSTILE_SECRET_KEY=...` with the other secrets on
   `supabase config push` (README).

## Not now

The visible widget, a captcha on anything after sign-in, Turnstile on the
marketing site.
