# Logging — design

Issue: #265. No Figma: nothing visible changes. Builds on #47 (Sentry) and
#46 (offline, `2026-10-10-offline-design.md`), whose network/unknown split
this reuses.

## Intent

When something goes wrong, a developer should be able to tell what and why:
locally from the console, from a tester's device from Sentry. Today an
unexpected error (a broken query, a malformed row, a `TypeError`) is caught by
`guardPeople` or `AuthRepository._guard`, becomes `unknown`, shows "something
went wrong", and its type and stack are gone. Sentry only sees what nobody
caught, with no trail of what led there.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Log API | `package:logging` 1.3.x, one top-level `Logger('<area>')` per file that logs (`people`, `auth`, `photos`, `router`). No wrapper class. | Published by dart.dev, no dependencies, already in the lockfile through Supabase. Named loggers and levels are all we need. |
| Sentry bridge | `sentry_logging` pinned to the `sentry_flutter` version (9.30.1); both move together. | Turns log records into breadcrumbs and events with no glue code. A mismatched version fails to resolve. |
| Breadcrumbs | `INFO` and above. | The integration's default. |
| Sentry events | `SEVERE` and above. | Same default. `SEVERE` means "a bug": a developer should look. |
| Sentry structured logs | On (`options.enableLogs = true`), `WARNING` and above. | Searchable in Sentry and cheap at this volume. `INFO` stays a breadcrumb so the quota isn't spent on navigation. |
| Console | Debug and profile builds print every record (`Level.ALL`) with `debugPrint`: level, logger, message, then error and stack if present. Release prints nothing. | Shows up in `flutter run`, the IDE and DevTools with no setup. |
| Sentry in debug | Stays off (empty DSN, as now). To try the pipeline, `flutter run --release`. | No new config or environment, and dev noise doesn't land in the testers' project. |
| What gets reported | In the two guards: `unknown` from a non-refusal is `SEVERE`, a server refusal that's expected (`AuthException`) is `WARNING`, network is `INFO`. Details in §2. | Bugs reach Sentry, expected failures leave a breadcrumb, being offline never pages anyone (#46). |
| Direct `Sentry.captureException` | Replaced by `log.severe` (in `PhotoRepository.discard`, the only call). | One way to report. It can be tested by listening to the logger; the offline spec couldn't test `discard` because Sentry is static. |
| Navigation trail | A listener on `router.routerDelegate` logs `INFO` `→ /path` (path only, no query). | `SentryNavigatorObserver` on `GoRouter` doesn't see pages inside the three `ShellRoute`s and would need wiring on each one. A listener is one line and covers them all. |
| HTTP trail | `Supabase.initialize(httpClient: SentryHttpClient(captureFailedRequests: false))`. | Breadcrumbs with method, URL, status and duration for every Supabase call. Failed requests are already reported by the guard, with better context. |
| URLs in breadcrumbs | `beforeBreadcrumb` drops `http.query` and `http.fragment`. | Signed Storage URLs carry a token in the query, and PostgREST filters can carry values. |
| User on events | `scope.setUser(SentryUser(id: <supabase uid>))` on every auth change, `null` on sign-out. Id only. | Lets you match a report to rows. No email (PII stays off). |
| PII in messages | Never put names, emails, phones, notes or event titles in a log message. Ids and counts are fine. A `PostgrestException` is logged without `details` and `hint`. | Postgres puts row values in `details` ("Key (email)=(…)"). `message` and `code` don't contain them. |
| Riverpod `ProviderObserver` | Not now. | Provider errors come from repositories, which already go through the guards. Add it if a failure shows up that the guards miss. |
| Log levels per area at runtime | No. | YAGNI. |

## 1. Setup (`lib/main.dart`)

Inside `SentryFlutter.init`'s options:

- `options.addIntegration(LoggingIntegration(minSentryLogLevel: Level.WARNING))`
- `options.enableLogs = true`
- `options.beforeBreadcrumb`: remove `http.query` and `http.fragment` from
  `breadcrumb.data`

Before `SentryFlutter.init`:

- `recordStackTraceAtLevel = Level.SEVERE`, so a `severe` without a stack
  still points at its call site, not at Sentry's internals.
- Outside release: `Logger.root.level = Level.ALL` and an `onRecord` listener
  that calls `debugPrint`. In release the root level stays `INFO`, the
  default.

In `appRunner`: `Supabase.initialize(..., httpClient: SentryHttpClient(captureFailedRequests: false))`,
then listen to `onAuthStateChange` and set the Sentry user: the session's user id,
or `null` without a session.

## 2. The guards

`guardPeople` (`features/contacts/data/people_repository.dart`) catches
`(error, stack)` and, before rethrowing the mapped failure:

| Error | Level |
| --- | --- |
| Already a `PeopleFailure` | none (already logged where it was raised) |
| Maps to `network` | `info('offline', error)` |
| `PostgrestException` | `severe('${e.code}: ${e.message}', PostgrestException(message: e.message, code: e.code), stack)` |
| Anything else mapped to `unknown` | `severe('unexpected', error, stack)` |

`guardAuth` (was `AuthRepository._guard`, now next to `authFailureFrom`):

| Error | Level |
| --- | --- |
| Maps to `network` | `info` |
| `AuthException` (any mapping) | `warning('${e.code} ${e.statusCode}')`: wrong passwords, rate limits and "email exists" are expected; an unrecognised code is worth seeing but isn't a bug |
| Anything else | `severe('unexpected', error, stack)` |

The rule for both: a bug is `SEVERE`, a refusal is `WARNING`, the connection
is `INFO`. The mapping functions stay pure. Only the guards log.

## 3. Other log lines

- `PhotoRepository.discard`: `log.severe(...)` replaces
  `Sentry.captureException`. Unreachable Storage stays silent, as now.
- Router: `INFO` `→ ${router.state.uri.path}` on every change, in
  `routerProvider`; the listener is removed in `ref.onDispose`.

Other log lines come with the features that need them, at the level from the
rule above.

## 4. Testing

- Unit (`people_repository_test.dart`, `auth_failure_mapping_test.dart`):
  listen to the area's logger and check that a network error logs `INFO`
  only, a `PostgrestException` logs `SEVERE` without `details`, an
  `AuthException` logs `WARNING`, a `TypeError` logs `SEVERE` with its stack.
  For this, `AuthRepository._guard` becomes a top-level `guardAuth` next to
  `authFailureFrom`, mirroring `guardPeople`.
- `discard` stays checked by reading its one `if`: building a
  `PhotoRepository` needs a `SupabaseClient` with a fake `http.Client`, and
  `http` isn't a dependency.
- The Sentry wiring (integration, `beforeBreadcrumb`, user, HTTP client) isn't
  unit-tested. Check it once with `flutter run --release`: force a failure and
  confirm the event in Sentry has the user id, the route and HTTP breadcrumbs,
  and no query strings.

## 5. Delivery

One PR: the two dependencies, `main.dart`, the guards, `discard`, the router
listener, tests. `docs/architecture.md` gets a short *Logging* paragraph with
the level rule and the PII rule.
