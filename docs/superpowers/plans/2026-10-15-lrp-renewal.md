# LRP Renewal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A customer's LRP renews on a day of the month (#317, part of #313). From 3 days before each renewal, Today shows "Julie's LRP renews Oct 15", ticked with the ring. If it isn't ticked, it drops off after the renewal day, and next month it comes back by itself. It doesn't touch the person's workflow. The day is set on the contact's LRP sheet and in What's next's LRP question.

**Architecture:**
- **Migration:**
  - `person.loyalty_day` (1–28) and `person.loyalty_checked_for`, with `loyalty_day` backfilled from `loyalty_since`;
  - `set_loyalty` fills the day when it is null and clears it on stop;
  - `loyalty_renewal_on(person, day)` gives the renewal due on that day, or null;
  - `check_loyalty` records the tick;
  - `due_people_count` counts due renewals.
- **Dart:**
  - `loyaltyRenewal(person, today)` is the same rule, pinned by the same cases;
  - `DueLoyalty` on Today;
  - a day field on the LRP sheet and in What's next.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, Supabase (Postgres, pgTAP).

**Spec:** `docs/superpowers/specs/2026-10-13-workflows-events-design.md` (Decisions: LRP follow-up; §1 LRP; §4 Today, Contact page, What's next sheet). Figma: "Today — new rows" (LRP), "What's next — customer, LRP question".

## Global Constraints

- One migration, `supabase migration new loyalty_renewal`.
- **Database:**
  - push after merge, before the release;
  - safe for the released app: new columns, same-signature replacements of `set_loyalty` and `due_people_count`, and new functions;
  - the tick writes a `reminder` entry, a kind the released app already reads.

  Quirk until people update: the push counts due renewals that the released Today can't show.
- Rule in Postgres and its Dart copy in the domain, each pinned by the same cases: February, day 28, before / on / after the day, already checked.
- No new dependency. Copy in `app_en.arb` only, described. Gate: `dart format .`, `flutter analyze`, `flutter test`, `supabase test db`. Goldens through CI.
- Branch `feature/317-lrp-renewal`; PR `Closes #317`, Database section filled.

## Rulings made while planning

- **The tick writes a `reminder` entry, not a new `loyalty_check` kind.**
  - The released app throws on an activity kind it doesn't know, so a new kind would break history for anyone who hasn't updated.
  - The text comes from the device ("Julie's LRP renews Oct 15") and is passed to `check_loyalty`. Today's done counter and last contact already count reminders.
  - Recorded as a change to the spec's decision.
- **No ordinals.** The row says "renews Oct 15", a formatted date, rather than "on the 15th": ICU ordinals aren't worth it in two languages.
- **The renewal is today's or the next month's.** `renewal(today)` is the day `loyalty_day` of this month if that hasn't passed yet, otherwise of next month. It is due when `today >= renewal − 3` and `loyalty_checked_for` is not that renewal. A renewal that has passed is therefore never due: next month's has taken its place.
- **Ticking an already-checked renewal adds nothing.** `check_loyalty` refuses someone without an LRP (P0001).
- **The day is a direct write** (`PeopleRepository.setLoyaltyDay`), the same update grant as the other person fields. The LRP sheet and What's next call it after `setLoyalty` when the day picked differs from the one `set_loyalty` fills.
- **Today row:**
  - **Day:** `renewal − 3`, for the order. No late chip: it is never late.
  - **Copy:** `loyaltyLabel(model)` names the programme ("LRP" for dōTERRA).

## Review Focus

1. The renewal rule in SQL and Dart agrees on: Feb 28, the 31st capped to 28, 4 days before (not due), 3 days before, the day itself, the day after, already checked. Pinned in Tasks 1 and 2.
2. Ticking writes once and the row leaves; the next month it is back. Pinned in Tasks 1 and 3.

---

### Task 1: Migration and pgTAP

**Files:** Create `supabase/migrations/<ts>_loyalty_renewal.sql`, `supabase/tests/loyalty_renewal_test.sql`.

- [x] **Step 1: Failing pgTAP.**
  - **Backfill:** `loyalty_since` 2026-03-31 → `loyalty_day` 28.
  - **`set_loyalty`:**
    - a start on 10-15 fills day 15;
    - a move keeps the day;
    - a stop clears it.
  - **`loyalty_renewal_on`, day 15:**
    - 10-11: null;
    - 10-12: 10-15;
    - 10-15: 10-15;
    - 10-16: null (next is 11-15, not yet due).
  - **`loyalty_renewal_on`, day 28:** 2027-02-25 → 2027-02-28.
  - **No LRP:** null.
  - **`check_loyalty`:**
    - writes one reminder entry, and the renewal is then not due;
    - a second call adds nothing;
    - someone without an LRP: P0001.
  - **`due_people_count`:** counts a due renewal.
- [x] **Step 2: Migration.**
  - **Columns and backfill:** add the columns, then `update person set loyalty_day = least(extract(day from loyalty_since), 28) where loyalty_since is not null`.
  - **`set_loyalty`:** `create or replace` from `20261010130800`, with `loyalty_day = case when p_since is null then null else coalesce(target.loyalty_day, least(extract(day from p_since)::int, 28)) end`.
  - **`loyalty_renewal_on(p person, p_on date) returns date`** (sql):

    ```sql
    with r as (
      select case
        when extract(day from p_on) <= p.loyalty_day
          then make_date(year, month, loyalty_day) of p_on
        else that of p_on + 1 month
      end as renewal
    )
    select renewal from r
    where p.loyalty_since is not null and p.loyalty_day is not null
      and p_on >= renewal - 3
      and p.loyalty_checked_for is distinct from renewal
    ```

  - **`check_loyalty(p_person, p_renewal date, p_on date, p_text text) returns person`:** locks the person, refuses without an LRP, and returns the row unchanged when `loyalty_checked_for = p_renewal`. Otherwise it inserts `activity (kind 'reminder', text p_text, happened_on p_on)` and sets `loyalty_checked_for`.
  - **`due_people_count`:** gains `or public.loyalty_renewal_on(p, p_on) is not null`.
  - **Grants:**
    - `loyalty_renewal_on` to `authenticated` and `service_role`;
    - `check_loyalty` to `authenticated`;
    - both revoked from `public` and `anon`.

### Task 2: Model, rule, repository

**Files:**
- Modify: `person.dart`, `people_repository.dart`, `people_controller.dart`, `fake_people_repository.dart`, `server_rule.dart` (copies).
- Create: `lib/features/contacts/domain/loyalty_renewal.dart`.
- Test: `test/features/contacts/domain/loyalty_renewal_test.dart`, `people_repository_test.dart`, `people_controller_test.dart`.

- [x] **Step 1: Failing tests.**
  - `loyaltyRenewal` with the same cases as Task 1.
  - Row mapping reads `loyalty_day` and `loyalty_checked_for`.
  - Controller:
    - `checkLoyalty` replaces the person, and the fake records `checkLoyalty(p1:2026-10-15)`;
    - `setLoyaltyDay` records `setLoyaltyDay(p1, 20)`.
- [x] **Step 2:**
  - **`Person`** gains `loyaltyDay` and `loyaltyCheckedFor`.
  - **`personFromRow`** reads them, and `personToRow` never writes them.
  - **Repository:**
    - `checkLoyalty(id, renewal, on, text)` calls the RPC with `.select(_columns).single()`;
    - `setLoyaltyDay(id, day)` goes through `_write`.
  - **Controller methods** use `_replace`.
- [x] **Step 3: Fake.**
  - `setLoyalty` fills and clears the day as the server does.
  - `checkLoyalty` sets `loyaltyCheckedFor`, adds a reminder entry, and refuses without an LRP.

### Task 3: Today, the LRP sheet, What's next

**Files:**
- Modify: `due.dart`, `today_page.dart`, `today_preview.dart`, `loyalty_sheet.dart`, `whats_next_sheet.dart`, `contact_details.dart`, `app_en.arb`.
- Test: `due_test.dart`, `today_page_test.dart`, `test/features/contacts/presentation/loyalty_sheet_test.dart`, `whats_next_sheet_test.dart`.

- [x] **Step 1: Failing tests.**
  - **`dueToday`:** a due renewal → `DueLoyalty`, keyed `lrp:<id>`, dated renewal − 3.
  - **Today:**
    - the row reads "Julie's LRP renews Oct 15";
    - ticking calls `checkLoyalty` with that text, and the row leaves.
  - **LRP sheet:** the Renews on day field (1–28) defaults to the person's day. A different day saves `setLoyaltyDay`.
  - **What's next:** Yes shows the day field. A different day saves after `setLoyalty`.
  - **Contact:** the LRP line adds "· renews on day 15".
- [x] **Step 2: Copy.**
  - `todayLoyaltyRenews` ({name}, {label}, {day} `MMMd`) "{name}'s {label} renews {day}";
  - `loyaltyRenewsOn` ({label}) "{label} renews on day";
  - `loyaltyRenewsHint` "Day of the month, 1 to 28.";
  - `contactLoyaltyRenews` ({line}, {day}) "{line} · renews on day {day}".

  Each with a description.
- [x] **Step 3: UI.**
  - **Today:**
    - `DueLoyalty(person, renewal)`, ranked after reminders;
    - `_tick` calls `people.checkLoyalty(person, renewal, today(), text)`, with the text from `todayLoyaltyRenews`;
    - no late chip.
  - **The LRP sheet and What's next:** a `DropdownButtonFormField<int>` over 1–28.
  - **Contact:** the LRP line with its day.
  - **Preview:** `_book` gains one `DueLoyalty`.

### Task 4: Gate

- [x] `dart format .`, `flutter analyze`, `flutter test`, `supabase test db`, `graphify update .`; goldens through CI; PR with the Database section.

## Found while implementing

- **A stop also clears `loyalty_checked_for`**, so an LRP started again isn't treated as already checked.
- **`renewalDayFor(since)`** in `loyalty_sheet.dart` is the Dart side of `set_loyalty`'s default day. Both sheets compare against it to skip the second write.
- **The LRP sheet's day follows the start day** until it is picked, for an LRP that has no day yet.
- **Across a year** (a renewal on Jan 2 is asked on Dec 30) is pinned in both SQL and Dart.
- **The Today widget test picks a renewal day 1–28** within the next 3 days, so it runs on every date.
- **Goldens:** `today_*`, for Anna's renewal row.
