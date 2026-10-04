# Desktop columns — design

Date: 2026-10-04. Issue: to be opened, with #145 folded in.

## Why

Testing the web after the goals epic showed:

- Today, Team and Goals draw a single 624px column against the left edge of the main panel. The rest of a desktop window stays empty.
- Planning (`/goals/plan`) and closing (`/goals/close`) stretch every field across the whole window.
- The contact detail's facts column is 272px, too cramped for "What they are aiming for" and "What you know". Next step and history stretch across the rest.

`docs/design/responsive-design.md` already asks for two real columns on desktop (Today, Goals, Team) and a split contact pane. The app was built with one column only. This design builds the two columns.

## Scope

Desktop only (`context.screenSize.isDesktop`, ≥ 1024px). Mobile and tablet don't change: each screen keeps its current single-column order. The visual identity doesn't change either; only the layout adapts. Nothing new is fetched or invented: the columns rearrange pieces the app already has.

## Layout: `ContentColumns`

One widget in `lib/core/layout/content_columns.dart`:

- `ContentColumns({required List<Widget> main, required List<Widget> side, double sideWidth = 400})`.
- **Desktop:**
  - A `Row` with both columns aligned to the top. The side column has a fixed `sideWidth`; the main column takes the rest, capped at 624px. They're separated by `AppSpacing.xl`.
  - The pair is centred inside a 1440px maximum, so a wide window gains margins, not a third column.
- **Below desktop:** `main` then `side` in one column. Screens that interleave the two on mobile keep their own mobile path and use `ContentColumns` only on desktop.
- **Scrolling:** one scroll for the whole page; both columns scroll together. Pull-to-refresh and the top bar stay in place, and the top bar spans the main column. A sticky side column is out of scope.

## Screens

**Today**
- **Main:** the top bar, the hero, then PRIORITY.
- **Side:**
  - the own-volume `GoalCard`, which replaces the one-line goal on desktop and opens Goals when tapped;
  - the close-and-plan `RitualCard` while `pendingRitual` asks;
  - WORTH A CHECK-IN, the same rows and check-in action as on Team.
- **Mobile and tablet:** unchanged, with the one line under the hero.

**Goals**
- **Main:** the volume card, the four tiles, the declared row, the pace card, `Log my own order`, `Change the plan`.
- **Side:**
  - the `RitualCard` in the window;
  - "Orders in October", listed inline: the same rows, delete confirmation and refresh as the orders sheet. The list is extracted from the sheet so both share it;
  - PAST MONTHS.
- **The volume card doesn't open the sheet on desktop:** the list is already there.
- **The empty state** ("What are you aiming for this month?") stays one centred column.

**Team**
- **Main:** EVERYONE (the roster).
- **Side:** the summary card, then WORTH A CHECK-IN.

**Contact detail (desktop pane)**
- **Main:** NEXT STEP, then HISTORY, capped at 624px.
- **Side:** WHERE IT STANDS (prospects), WHAT THEY ARE AIMING FOR (team), WHAT YOU KNOW.
- **Width:** `sideWidth: 340`, up from 272. At a 1440px window the pane is 752px (1440 − 248 sidebar − 440 list), which leaves the main column about 390px. On wider windows the main column grows to its cap.
- **The header** (name, Message / Call / ⋯) spans both columns, as now.

**Planning and closing (`/goals/plan`, `/goals/close`)**
- **One centred column capped at 624px** on every size above mobile, with the back arrow aligned to it. A form has one column at every width, as on the auth screens.

## Figma first

Before any code, in the existing file (`spz2vsSK8gbt1Ok2rW1sdQ`):

- **Desktop frames**, 1440 × 900: Today, Goals, Team, the contact detail with the wider facts column, and planning centred.
- **#145's library fixes:**
  - a `value` property on the progress bar;
  - a Switch component, which the loyalty step uses;
  - a unit slot on the text field ("PV");
  - the StatTile value at 20px;
  - the sidebar wordmark "Loomia" instead of "Folo" (#81).

You review the frames; the code follows them.

## Tests

- **`ContentColumns`:**
  - at 390px it stacks main then side;
  - at 1440px the side column sits to the right of the main one at `sideWidth`;
  - at 1920px the pair is centred within 1440px.
- **Each screen, at desktop size:** a widget test that the side content is to the right of the main content, and the screen's own pieces are where the design says. Examples: on Today the `GoalCard` is in the side and the one-line goal is gone; on Goals the orders are listed inline.
- **Planning and closing:** at 1440px, the form is at most 624px wide and centred.
- **Goldens:**
  - `today_desktop_*`, `goals_desktop_light` and `contacts_desktop_light` change;
  - a `team_desktop_light` preview exists already and changes;
  - planning gets a desktop preview, `goals_plan_desktop_light`.

  All are regenerated through CI.

## Out of scope

- Tablet two-column layouts above 840px in landscape (the responsive doc's tablet row).
- Keyboard shortcuts and focus rings from the desktop section of the responsive doc.
- A sticky side column, and independent scrolling.
- Any new data or feature on the right columns.
