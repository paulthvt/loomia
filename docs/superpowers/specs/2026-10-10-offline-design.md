# Offline — design

Issue: #46. No Figma: the offline state reuses `EmptyState`
(`lib/core/ui/empty_state.dart`), no new pattern. The background token
refresh that reached Sentry offline was fixed on its own in #260.

## Intent

Loomia is online-only: no local cache, no sync. When the network is gone,
every screen that cannot load says so plainly, offers Try again, and nothing
reaches Sentry. A bug or a server refusal still reads as "something went
wrong", not as the user's connection.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Offline data | None. | Set in #46: offline-first means sync and conflicts for an app nobody uses without a connection. |
| Detection | From failed requests, no connectivity package. | A failed request is what matters; no new dependency. |
| Global banner | None. | Without a connectivity package it could only clear on the next successful request, which the per-screen Try again already is. Add one with `connectivity_plus` if users ask. |
| Where it shows | Every load-failure state already in the app, by swapping its copy. | They already show `cloud_off` and Try again; only the words are wrong. |
| Offline vs anything else | Offline: "You're offline". Otherwise: the screen's own "Couldn't load …" title with a body that does not blame the connection. | Today every failure says "Check your connection", including bugs. |
| Shared widget | `LoadFailed` in `core/ui/`, taking `offline: bool`. | `core/` must not import `PeopleFailure` from `features/contacts`; callers pass `error == PeopleFailure.network`. |
| Inline failures (orders, history, next step) | Keep their row, swap the text. | A full empty state inside a section is a card in a card. |
| Writes | Unchanged: the existing snackbar ("Couldn't save. Check your connection…"). | Already right. |
| Storage offline | Recognised as network. | `storage_client` wraps a socket error in `StorageException` with the exception's type as `statusCode` (not a number); today that maps to unknown. |
| `discard` reporting | Report everything except an unreachable Storage. | A file left behind offline is expected, not a bug. |
| `authFailureFrom` | Any other `Exception` except `FormatException` is network, as in `peopleFailureFrom`; drop `dart:io`. | `deleteAccount` goes through `functions.invoke`, which throws `http.ClientException`, not `SocketException`. gotrue calls already arrive as `AuthRetryableFetchException`. |
| `photoUrlProvider` | Unchanged. | Riverpod's default retry (10 tries, up to 6.4 s apart) recovers a short drop; errors stay in the provider and the avatar shows initials. ponytail: after a long outage, initials until restart. |

## 1. Recognising a network failure

`peopleFailureFrom` (`features/contacts/data/people_repository.dart`):

```dart
final StorageException e when storageUnreachable(e) => PeopleFailure.network,
```

before the existing `StorageException` arm. `storageUnreachable` (next to
`PhotoRepository`): `statusCode` is set and is not a number. A refusal
without a status (`StorageException('Payload too large')`) stays unknown. `PostgrestException` stays
unknown (it is always a server answer); socket, `ClientException` and timeout
already fall into `Exception() => network`.

`authFailureFrom`: the final `SocketException || TimeoutException` check
becomes `FormatException` → unknown, then `Exception` → network, the same
order as `peopleFailureFrom`.

`PhotoRepository.discard`: catch everything as now, but only call
`Sentry.captureException` when the error is not a `StorageException` for
which `storageUnreachable` holds (a bug still reports).

## 2. `LoadFailed`

`lib/core/ui/load_failed.dart`:

```dart
LoadFailed({required bool offline, required String title, required VoidCallback onRetry})
```

An `EmptyState` with `cloud_off_outlined`, `contactsRetry` as the action, and:

| | Title | Body |
| --- | --- | --- |
| `offline` | `offlineTitle` | `offlineBody` |
| otherwise | `title` | `loadFailedBody` |

It replaces `PeopleLoadError` (contacts), `WorkflowsLoadError` (workflows),
`_Failed` (Today) and the inline `EmptyState`s in `calendar_page`,
`event_page` (×2), `goals_page`, `plan_page`, `close_page`,
`workflow_timeline_page`. Each passes its existing title key and
`offline: <asyncValue>.error == PeopleFailure.network`.

Inline rows: `orders_sheet` (`ordersLoadFailed`), `history_section`
(`historyLoadError`), `next_step_section` (`nextStepLoadFailed`) show
`offlineInline` instead when offline.

## 3. Copy

New keys in `app_en.arb`, each with a description:

| Key | EN |
| --- | --- |
| `offlineTitle` | You're offline |
| `offlineBody` | Loomia can't be reached. Check your connection, then try again. |
| `offlineInline` | You're offline. |
| `loadFailedBody` | Something went wrong on our side. Try again in a moment. |

`contactsLoadErrorBody` goes once nothing uses it. FR comes from the l10n
sync, informal register.

## 4. Architecture

`docs/architecture.md` → *Not yet present, by design* gains **Online-only**:
no local data beyond the Supabase session; a failed request is the offline
signal; `PeopleFailure.network` / `AuthFailure.network` are the only places
that decide it; `LoadFailed` is the only presentation.

## 5. Checked, no change

- Startup: `supabase_flutter` 2.18.2 `recoverSession` catches its own errors;
  launching offline does not throw.
- Auto-refresh: gotrue catches it; its stream error is #260.
- Async providers turn errors into `AsyncError` values; widgets read them, so
  they are not reported to the zone.

## 6. Testing

- Unit: `peopleFailureFrom` (a `StorageException` with `statusCode`
  `'ClientException'` is network, `'413'` unknown); `authFailureFrom` (a
  plain `Exception` is network, `FormatException` unknown; `http` is not a
  direct dependency, so no `ClientException` in tests).
- Widget: `LoadFailed` offline and not; one screen per shape — Today offline
  shows `offlineTitle`, Today with `PeopleFailure.unknown` shows
  `todayLoadFailed` and `loadFailedBody`; history offline shows
  `offlineInline`.
- `discard`: not unit-tested (Sentry is static); the rule is one `if`.
- Goldens: any changed `@Preview`, regenerated through CI.

## 7. Delivery

One PR for #46.
