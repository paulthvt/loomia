# Design system

Direction B (Fresh & Energetic) with the **L1 Ocre pale** Loomia palette,
circular avatars, light and dark fully specified.

Source of truth: [Figma → Loomia](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia),
page `Foundations`. Variables: collection `Loomia/color` (modes `Light` / `Dark`)
and `Loomia/scale` (single mode). Every fill, stroke, padding and radius in every
component and screen is **bound to a variable** — no literal colour exists
outside the two exploration pages.

The tokens live in `lib/app/theme/` (see §8 for the file-by-file mapping) and are
visible in `flutter widget-preview start` — group **Tokens**. Components and
screens are not implemented yet.

---

## 1. Colour

### Why these hues

`brand` is the Loomia ochre `#E8964A` — logo, app icon, decorative marks. White
on it is 2.4:1, so it **never sits behind text**. `primary` is the same hue
walked darker until white text passes AA; `primary/text` walks it lighter for
ink on dark surfaces. One hue, three jobs.

Secondary is a muted **slate blue**: a cool counterpoint, so "on pace" never
reads as a second shade of the brand. Accent (plum) and warning (olive-gold) sit
away from ochre, and error is crimson rather than orange-red, so none of them can
be mistaken for the brand. Neutrals are warm (hue 30°) at the lightness the
previous palette was calibrated at.

Accent is reserved for things anchored to a real moment — a birthday, a promised
call-back — never for judgement (guardrail #2).

### Semantic tokens

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `brand/base` | `#E8964A` | `#E8964A` | Logo, app icon, decorative marks. Never behind text. |
| `surface/canvas` | `#FBFAF8` | `#120F0C` | App background. Warm off-white / hue-tinted near-black, never `#000`. |
| `surface/default` | `#FFFFFF` | `#1E1A15` | Cards, rows, bars. |
| `surface/raised` | `#FFFFFF` | `#26211C` | Menus, sheets, dialogs. In dark, raised steps *up* a surface instead of deepening a shadow. |
| `surface/sunken` | `#F4F1EE` | `#181411` | Search field, sidebar, wells. |
| `surface/disabled` | `#F2EFEC` | `#211E1A` | Disabled controls. |
| `border/subtle` | `#E8E4E1` | `#312C26` | The default 1px hairline. |
| `border/strong` | `#CFC8C0` | `#48413A` | Unchecked controls, dividers that must be seen. |
| `text/primary` | `#201B16` | `#F1EEEC` | Names, headings, values. |
| `text/secondary` | `#57524C` | `#C2BCB7` | Body, reasons, descriptions. |
| `text/muted` | `#706A64` | `#A59E97` | Metadata, overlines, captions. |
| `text/on-primary` | `#FFFFFF` | `#FFFFFF` | Text on `primary/base` — same in both modes, because the hero block is the same colour in both modes. Also the hero's progress bar. |
| `text/on-secondary` | `#0B111E` | `#0B111E` | Text on `secondary/base`. |
| `text/disabled` | `#A9A49F` | `#68625C` | |
| `primary/base` | `#A75C15` | `#A75C15` | The filled hero, primary buttons. **Identical in both modes.** |
| `primary/hover` | `#8C4C12` | `#B06017` | Pointer hover; also the hero's own progress track. |
| `primary/text` | `#995413` | `#D38A45` | Primary used as *ink* — this is the token that must flip, since the base fails contrast on dark surfaces. |
| `primary/container` | `#F2E8DE` | `#271E16` | Tinted blocks, active nav pill, avatar background. |
| `primary/on-container` | `#713E0E` | `#E0AB7B` | Ink on `primary/container`. |
| `primary/muted` | `#F9F5F1` | `#1A140F` | Hover wash, selected row. |
| `secondary/base` | `#697DAB` | `#909FC1` | Progress bars. The pace colour. |
| `secondary/text` | `#495B83` | `#909FC1` | "On pace", pace labels. |
| `secondary/container` | `#E5E7EB` | `#1B1D22` | Tinted stat tile. |
| `secondary/on-container` | `#3D4B6C` | `#AAB5CF` | |
| `secondary/track` | `#CBCFD8` | `#2D3139` | Progress track under `secondary/base`. |
| `accent/base` | `#A94C8D` | `#BF87AE` | Date-anchored marks only. |
| `accent/container` | `#EDE3EA` | `#231B20` | Date chips (birthday, promised call-back). |
| `accent/on-container` | `#71335E` | `#D1A9C5` | |
| `semantic/success` | `#2E7D5B` | `#5FC196` | Confirmation of a system action. |
| `semantic/success-container` | `#DCEFE4` | `#13291F` | |
| `semantic/warning` | `#8A690F` | `#BC9529` | System states only (sync, permission). Olive-gold so it cannot be read as `brand` or `accent`. |
| `semantic/warning-container` | `#F2EDDE` | `#272316` | |
| `semantic/error` | `#CF3046` | `#D5818C` | Destructive actions and genuine validation errors. Never "overdue" (principle #4). |
| `semantic/error-container` | `#F0E0E2` | `#25181A` | |
| `semantic/on-error` | `#FFFFFF` | `#241110` | |
| `semantic/info` | `#2C6B7A` | `#74BDCB` | Neutral system notice. |
| `semantic/info-container` | `#DDEDF1` | `#14282E` | |
| `state/focus` | `#995413` | `#D38A45` | 2px focus-visible ring. |

Scopes are set on every variable (`FRAME_FILL, SHAPE_FILL` for surfaces,
`TEXT_FILL` for ink, `STROKE_COLOR` for borders) so the Figma colour picker only
offers tokens that make sense in the slot being edited.

### Rules that come out of the palette

1. **One filled colour block per screen** — the Today hero. Everything else is
   surface plus hairline (guardrail #1).
2. **Tinted pairs, not tinted everything** — at most one `primary/container` /
   `secondary/container` pair per screen (the stat tiles).
3. **Accent means "a date made this urgent"**, never "you are behind".
4. **Red only destroys.** The one exception is a field-level validation error.
5. **Dark is not an inversion.** Canvas is hue-tinted near-black, surfaces step
   up, the hero keeps its light-mode colour, and every *ink* use of primary /
   secondary / accent switches to the lighter tint.

### Contrast

All body and label pairs clear WCAG AA (4.5:1); `text/muted` on `surface/canvas`
is 5.1:1 light and 7.2:1 dark. `text/on-primary` on `primary/base` is 5.0:1 in
both modes, and 4.6:1 on dark `primary/hover`; `primary/text` is 5.8:1 on white
and 6.2:1 on dark `surface/default`. The hero's secondary labels are white at
94% opacity (`AppColors.quietOnPrimary`, 4.6:1): ochre leaves less headroom than
the old forest did, so hierarchy there comes from size and weight, not fading.
`test/app/theme/app_theme_test.dart` pins all of these.

---

## 2. Typography

**Plus Jakarta Sans**, one family, four weights (Regular / Medium / Bold used;
variable font, so four weights cost one file).

Why: wide apertures and a tall x-height keep 13px legible on Android; true
tabular figures keep goal numbers from shifting as they update; the skeleton is
geometric enough to read as a product and neutral enough not to carry an opinion
of its own. A serif display face was considered (Direction C) and dropped — it
adds a webfont on Web and is the wrong risk for a 25–65 audience.

| Style | Size / line | Weight | Tracking | Use |
| --- | --- | --- | --- | --- |
| `display` | 32 / 38 | Bold | −1.5% | Desktop greeting, contact name on desktop detail. |
| `headline` | 24 / 30 | Bold | −1% | Mobile screen title, contact name on mobile. |
| `title-lg` | 20 / 26 | Bold | −0.5% | Hero headline, dialog title, empty-state title. |
| `title` | 17 / 24 | Bold | — | Person's name in a row. The most-used heading in the product. |
| `body-lg` | 16 / 24 | Regular | — | Input values, dialog body, sentences that matter. |
| `body` | 15 / 22 | Regular | — | Default body. |
| `body-sm` | 13 / 18 | Regular | — | The reason line under a name. |
| `label-lg` | 15 / 20 | Bold | — | Buttons, sidebar items. |
| `label` | 13 / 16 | Bold | — | Field labels, small actions. |
| `caption` | 12 / 16 | Medium | — | Metadata, pace, nav labels. |
| `overline` | 11 / 14 | Bold | +10%, UPPER | Section headers, stat-tile labels, date eyebrows. |
| `numeric-lg` | 30 / 34 | Bold | −1% | Stat-tile values. |
| `numeric` | 20 / 24 | Bold | −0.5% | Goal values. |

Numerals use `FontFeature.tabularFigures()` in Flutter. Goal numerals cap at
30px and never exceed the greeting (guardrail #4). Uppercase is only ever
`overline` — never a heading, never a button.

---

## 3. Spacing

A 4-based scale, in `Loomia/scale`:

| Token | px | Typical use |
| --- | --- | --- |
| `space/xs` | 4 | Name → reason, chip internals. |
| `space/sm` | 8 | Chip gaps, label → field, icon → text. |
| `space/ms` | 12 | Row internals, list item gaps. |
| `space/md` | 16 | Card padding, screen horizontal padding (mobile). |
| `space/lg` | 24 | Between groups inside a screen. |
| `space/xl` | 32 | Between sections on desktop, desktop pane padding. |
| `space/xxl` | 48 | Desktop main-column horizontal padding. |
| `space/xxxl` | 64 | Reserved for marketing / empty screens. |

This replaces the placeholder `AppSpacing` (which lacks 12, 16-as-`lg`, 20 and
64) — see the Flutter mapping below.

---

## 4. Shape

| Token | px | Applies to |
| --- | --- | --- |
| `radius/sm` | 8 | Chips. |
| `radius/md` | 12 | Inputs, list rows with a hover/selected wash. |
| `radius/lg` | 16 | Cards, tiles, action items. |
| `radius/xl` | 20 | The Today hero, dialogs, bottom sheets. |
| `radius/pill` | 999 | Buttons, icon buttons, progress tracks, nav pill, **avatars at every size**. |

**Avatars are circular, always, everywhere** — 24 (inline), 32 (dense list /
stacks), 40 (list row), 56 (detail header). Decided 2026-09-22; squircle was the
alternative and lost on legibility at 24px and on photo crops.

Nothing is rounder than its container: a 16px card holds 12px inputs and 8px
chips.

---

## 5. Elevation

Three levels. Only two of them cast a shadow.

| Level | Spec | Where |
| --- | --- | --- |
| flat | no shadow, `surface/default`, 1px `border/subtle` | All content: cards, rows, tiles, bars. |
| `elevation/raised` | `0 1 2 @6%` + `0 2 8 @5%` | Menus, dropdowns, snackbars. **Never on a content card.** |
| `elevation/overlay` | `0 8 28 @12%` | Dialogs and bottom sheets only. Scrim: `text/primary` at 40%. |

In dark mode, raised and overlay surfaces step up a surface token
(`surface/default` → `surface/raised`) rather than deepening the shadow —
shadows are close to invisible on a near-black canvas.

A UI of floating cards is the thing this system is built to avoid (principle #6).

---

## 6. Iconography

**Material Symbols Rounded, outlined, weight 300** — 20px in dense contexts
(chips, inline), 24px default (nav, app bar, buttons). Stroke 1.75 at 20px.

Rationale: available through Flutter's bundled icon font, so it costs no
dependency (see CLAUDE.md — "adding a dependency requires a reason"); rounded
terminals agree with the pill/16px radii; outlined keeps icons quieter than the
names beside them.

Icons never carry meaning alone — every icon in navigation, and every icon-only
button, has a visible label or an accessible label. No icon is ever the only
indicator of state.

In Figma, icons are an `Icon` component used as an `INSTANCE_SWAP` slot with a
placeholder glyph; the production glyph comes from the Flutter font, so the
library deliberately does not ship 200 vector icons.

---

## 7. Motion

Restrained. Motion explains what moved, it never celebrates.

| Duration | Use |
| --- | --- |
| 120ms | Hover, pressed, focus ring. |
| 180ms | Chip/toggle state, small fades. |
| 240ms | List reorder, tab change. |
| 320ms | Sheet and dialog present/dismiss; a completed card sliding out. |

Easing: standard `cubic(0.2, 0, 0, 1)`, decelerate `cubic(0, 0, 0, 1)` for
entering, accelerate `cubic(0.3, 0, 1, 1)` for leaving.

Rules: no bounce or overshoot; no scale above 1.02; completing an action is a
check, then the card slides out to the start over 320ms while its slot closes,
the next step (if any) sliding in from the end at once (no confetti, no counter, no streak — principle
#5); no looping animation except an indeterminate loader; all of it respects
"reduce motion" by collapsing to a 120ms opacity change.

Fluidity comes from every screen using the same four durations and three curves,
not from springs. If a new interaction does not fit the table below, the
interaction is wrong before the table is.

### 7.1 Decision table

| Interaction | Duration | Curve | Flutter |
| --- | --- | --- | --- |
| Hover, press, focus ring | 120ms | standard | `InkWell` / `Material` states — state the wash, let the ink time it |
| Icon swap in place (reveal toggle) | 120ms | standard | `AnimatedSwitcher` |
| Tinted container changing tone | 120–180ms | standard | `AnimatedContainer` |
| Ink colour changing with state | 180ms | standard | `AnimatedDefaultTextStyle` |
| Label ↔ spinner on a button | 180ms | decelerate in, accelerate out | `AnimatedSwitcher` |
| Inline message appearing | 180ms | decelerate | `TweenAnimationBuilder` over opacity + `Align.heightFactor` |
| Progress bar value | 240ms | standard | `TweenAnimationBuilder` |
| Completed card out, next one in | 320ms | decelerate | `SlideSwap` (`lib/core/ui/slide_swap.dart`) |
| List reorder, tab change | 240ms | standard | `AnimatedSize` / `AnimatedList` |
| Page transition | platform | platform | a plain `MaterialPage` — the platform's own transition |
| Sheet, dialog | 320ms | standard | Material defaults from the component themes |

### 7.2 Page transitions belong to the platform

Routes use `pageBuilder:` returning a plain `MaterialPage`, never a
`CustomTransitionPage`. The page has to be named: go_router decides page type by
looking for a `MaterialApp` ancestor from `package:material_ui`, which is a
different class from the `flutter/material` one this app builds, so the check
always fails and every route silently falls back to `NoTransitionPage`.

The back gesture drags the page on both platforms: the Cupertino edge swipe on
iOS, predictive back on Android — which needs
`android:enableOnBackInvokedCallback="true"` in the manifest, or the engine never
sees the gesture and the transition only plays once the finger lifts. Flutter's default
transition per platform — Cupertino's slide with the edge-swipe on iOS, the zoom
on Android, both predictive-back ready — reverses correctly, tracks a drag, and
already is "one identity, native manners" (principle #7). A custom fade over
these seven flat routes bought nothing and got back-navigation wrong: the same
movement played in both directions, so the motion claimed a forward step while
the user went back.

This works because navigation inside a flow pushes and pops a real stack
(`context.push`, `context.pop` — see `lib/app/router/back.dart`). Direction comes
from the stack, never from a hand-written curve: a screen reached with `go`
replaces the location and has no "back" for motion to describe. If a new flow
wants a back gesture, it pushes.

Anything beyond the platform transition has to be earned by hierarchy — a list
opening a detail may later justify a shared axis. Seven sibling screens do not.

### 7.3 The reduce-motion contract

Durations never reach a widget as a literal. They arrive through
`context.motion(AppMotion.medium)` (`lib/app/theme/app_theme.dart`), which
returns 120ms whenever the platform asks for reduced motion. A movement whose
shape would still read as movement at 120ms — the 8px page shift — drops out
entirely instead; everything else keeps its fade. Using a raw `Duration` in a
widget is the bug, not the animation itself.

### 7.4 Never

Bounce, overshoot, elastic and spring curves. Scale above 1.02. Parallax.
Looping animation of any kind except an indeterminate loader. Staggered or
sequenced entrances — a list appears at once, or it is not ready. Page-load
fades on content that was already there. Any motion that reads as celebration:
counting numbers up, filling a ring, confetti, a streak (principle #5).

**One exception: the launch splash** (`lib/app/launch_splash.dart`). The ring
of the mark on brand ochre, the three dots growing in smallest first (400ms
each, 200ms apart, decelerate, no overshoot), a 250ms hold, then a 240ms fade
into the app — slower than the UI tokens, because this is watched, not used.
It is a brand moment on cold start, not UI, and it is the only staggered
entrance in the product. Reduce motion leaves only the fade. The native launch
screens (Android, iOS, web) draw the same ring at the same 96px, so the hand-off
to Flutter is invisible.

---

## 8. Mapping to Flutter

Implemented. One file per concern, no new dependency, no codegen.

- `lib/app/theme/app_colors.dart` — `AppColors.light` / `AppColors.dark`
  (`ColorScheme`) plus `LoomiaColors`, a `ThemeExtension` holding the tokens
  `ColorScheme` has no slot for (`surface/default|sunken|raised|disabled`,
  `border/subtle|strong`, `text/muted|disabled`, `primary/hover|text|muted`,
  `secondary/text|track`, `accent/*`, success / warning / info, `state/focus`).
  Read it with `LoomiaColors.of(context)`. A palette change is then one file.
- `lib/app/theme/app_spacing.dart` — `AppSpacing` (`xs` 4 → `xxxl` 64) and
  `AppRadii` (`sm` 8 → `pill`).
- `lib/app/theme/app_typography.dart` — `fontFamily = 'PlusJakartaSans'`, all 13
  styles as statics; the ones Material has a slot for are also wired into
  `TextTheme` (`displaySmall`, `headlineSmall`, `titleLarge`, `titleMedium`,
  `body*`, `label*`). `overline`, `numericLarge` and `numeric` have no Material
  slot and are used directly. The font is one bundled variable file, so each
  style sets the `wght` axis as well as `fontWeight`.
- `lib/app/theme/app_theme.dart` — the two `ThemeData`s and every component
  theme (buttons, input, card, chip, progress, dialog, sheet, menu, nav bar,
  list tile, tooltip), plus `AppElevation` (the two shadow sets and the scrim)
  and `AppMotion` (durations and easing) plus the `Motion` extension on
  `BuildContext` — `context.motion(duration)`, the one place "reduce motion" is
  honoured (§7.3).
- `lib/app/theme/theme_preview.dart` — `@Preview` token sheets (colour, type,
  spacing/shape/elevation, components) in both modes. `flutter widget-preview
  start`, group **Tokens**. Nothing in the app imports it.

Accent, success, warning and info deliberately do **not** occupy
`ColorScheme.tertiary`: one home per token, and Material widgets should not
reach a date-only colour by accident.

Widgets read `Theme.of(context)` and the extension only. The Figma variable name
`primary/container` maps to `LoomiaColors.primaryContainer`; the code syntax for
every variable is already set in Figma (`WEB`: `var(--loomia-primary-container)`,
`ANDROID`/`iOS`: `LoomiaColors.primaryContainer`), so Dev Mode reads the same names
the code uses.

---

## 9. Changing the palette later

Cheap by construction: ~24 values in one Figma variables panel and one Dart
file. What is *not* cheap: the token names and structure, the lightness
relationships the layouts depend on (dark primary block carrying a light
bar), and the number of accents. Hue is a value; the structure is the commitment.
