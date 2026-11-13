# Horizon theme — spec

Issue: #499. Mockups: `docs/design/horizon/*.png` (exported from the Figcraft file `Loomia.figcraft`, page "08 — Horizon (proposal)"). The PNGs are the visual reference; when this text and a PNG disagree, the PNG wins for looks and this text wins for behaviour.

## What

Restyle Loomia with the **Horizon** direction: a calmer, warmer look where one gradient "hero" per screen carries what matters now and everything else sits on quiet white cards. Layout and features stay the same; this is a visual change only.

Design: Figcraft file `Loomia.figcraft`, page **08 — Horizon (proposal)** (direction sheet, 10 mobile screens light + dark, 3 desktop screens). Explorations are archived on page 08b.

## Decisions

- **Hero gradient**: rosewood `#82424F` → apricot `#E39A68` at 135° (dark mode: `#4F2530` → `#A8623F`). Text sits in the dark top-left.
- **Amber `#A75C15` stays the action colour**: buttons, progress, active tab. Unchanged in both modes, as today.
- **Canvas** `#F6F2ED`, **cards** white with one soft shadow, no border; corners 24–28 on cards, 999 on chips, buttons and nav. Dark: canvas `#120F0C`, cards `#1E1A15`, hairline `#FFFFFF14` on the hero card and the bar.
- **Phone navigation**: a floating dark pill bar (`#2A181C`) on the four tabs only. Active tab = amber pill with label, others icons. A white **+** on the right of every tab creates what the tab is about: task (Today), event (Calendar), person (Contacts), own order (Goals). It replaces Add a task, the Calendar FAB, the add-person button and Log my own order. Detail screens (contact, event, task, notifications, month plan) have a back arrow and no bar.
- **Desktop**: the bar becomes a floating dark sidebar; the + becomes its first button, labelled (New task / New event / New person). The hero is a rounded band at the top of the main column; list + detail panes each get their own header.
- **Today, all done**: the hero card shows a gradient check badge, light confetti, "You're all done for today" and a warm line, in place of a bare full progress bar. No streaks, no score.
- **Section headers** become title case 18 bold ("People", "Tasks", "Catch up") instead of overlines.
- **Contacts** keeps the plain list (no hero card); search, filters and tags move into the gradient header.

## Out of scope

- Any change to data, flows or copy beyond the new "all done" line.
- Tablet-specific layouts (follows desktop).

## Done when

- Every screen in the page has its implementation, light and dark, phone and desktop.
- Goldens regenerated through CI and checked against the mockups side by side.
- `dart format .`, `flutter analyze`, `flutter test` clean.
- New copy in `app_en.arb` with descriptions; FR via Weblate.

## Tokens

| Token | Light | Dark |
| --- | --- | --- |
| canvas (`colorScheme.surface`) | `#F6F2ED` | `#120F0C` (unchanged) |
| card (`surfaceContainerLowest` / `surfaceDefault`) | `#FFFFFF` | `#1E1A15` (unchanged) |
| card shadow | `#201B16` at 7%, y 2, blur 8 | none |
| hero gradient, 135° | `#82424F` → `#E39A68` | `#4F2530` → `#A8623F` |
| hero card shadow | `#1E120A` at 20%, y 10, blur 30 | `#000000` at 40%, y 10, blur 30 |
| hero card hairline | none | `#FFFFFF14` |
| chrome (bar, sidebar) | `#2A181C` | `#2A181C` + hairline `#FFFFFF1A` |
| on chrome | `#FFFFFF`, muted `#FFFFFF` at 65% | same |
| on hero | `#FFFFFF`, quiet at 85%; translucent fills `#FFFFFF` at 18% (buttons), 12% (search, switch) | same |
| amber (primary) | `#A75C15` (unchanged) | `#A75C15` (unchanged) |

Radii: cards 24, hero card 28, hero bottom corners / desktop band 32, chips, buttons, nav 999 (pill). Screen margin 16. Content under the floating bar keeps 120 px of bottom room on phones.

## Screens

| Reference PNG | Screen | Hero holds |
| --- | --- | --- |
| today_mobile_*, today_desktop_light | Today | date, greeting, goal line, white hero card (eyebrow, headline, progress) |
| today_all_done_mobile_* | Today, list empty | same, the card shows the done badge, confetti, title, body, full bar, count |
| calendar_mobile_*, calendar_desktop_light | Calendar month | title + arrows, Month / 3 days / Week switch, month grid (phone); title, switch, Today, arrows (desktop band) |
| contacts_mobile_*, contacts_desktop_light | Contacts | count, title, search, filters, tags; list in one white card below |
| contact_mobile_* | Contact | back, more, avatar, name, since, stage + tags, Message (white) / Call (translucent) |
| event_mobile_* | Event | back, edit, delete, title, when, where, video + Join |
| task_mobile_* | Task | back, edit, delete, title, day, time + Bell on, repeat |
| goals_mobile_* | Goals | eyebrow, title, white hero card (own volume, progress, at-this-pace, Change the plan) |
| goals_plan_* | Plan the month | close, question, subtitle; filled inputs below |
| notifications_mobile_* | Notifications | back, title, subtitle |

Screens without a mockup (first run, workflows, settings, reports, tags, ritual) take the new tokens, cards and section headers but keep their current layout.
