# Responsive behaviour

One brand, one design system, adaptive layout. Identical colours, type, radii and
components on Android, iOS and Web; what changes is layout, density and input
conventions (principle #7).

No SwiftUI, no Cupertino component set, no per-platform visual identity.

---

## Size classes

Branch on `context.screenSize`, never on raw pixel widths in a widget.

| Class | Width | Navigation | Content |
| --- | --- | --- | --- |
| `mobile` | < 600 | BottomNav, 4 destinations | single column, 16px side padding |
| `tablet` | 600–1023 | Sidebar collapsed to 72px icon rail (portrait: BottomNav) | single wide column capped at 640, or two columns above 840 |
| `desktop` | ≥ 1024 | Sidebar 248px expanded | 2 columns (Today, Goals, Team) or list + detail (Contacts) |

Two behaviours cross a boundary that is *not* a size class edge and are therefore
named explicitly:

- **840px** — below this the sidebar is replaced by BottomNav.
- **1100px** — below this the expanded sidebar collapses to the 72px icon rail.

---

## Mobile (touch-first)

- One column, `space/md` (16) horizontal padding, `space/lg` (24) between groups.
- 44px minimum touch target on every interactive element; 64px list rows.
- TopAppBar carries the date as an eyebrow and collapses its title to `title-lg`
  on scroll. One trailing action, never two.
- BottomNav is always visible; it never carries badge counts.
- Dialogs present as bottom sheets with the same internals.
- Primary actions sit within thumb reach — on a contact, `Message` and `Call` are
  a full-width pair directly under the header, not in the app bar.
- Content scrolls under a fixed bar; nothing is horizontally scrollable except the
  filter chip row on Contacts.

## Tablet

- Portrait behaves like a wide mobile: BottomNav, single column capped at 640 and
  centred, which keeps line length readable instead of stretching body text.
- Landscape gets the 72px icon sidebar and, above 840px, the desktop two-column
  split with the right column narrowed to 320.
- Touch targets stay at mobile size — a tablet is a touch device.

## Desktop / Web (pointer + keyboard)

Desktop is designed, not enlarged:

- **Sidebar** 248px on `surface/sunken`: wordmark, four destinations, account
  pinned to the bottom.
- **Two-column content** on Today, Goals and Team (#171), one shared layout,
  `ContentColumns`: a fixed 400px side column, 32px apart, and the main
  column taking the rest, from the sidebar's edge. The pair stops at 1096px
  (its width at a 1440 window) and a wider window leaves the space after it;
  a narrower one shrinks the main column, never the side, and below a 300px
  main column the two stack. Today: hero and PRIORITY, beside the own-volume card, the
  close-and-plan card and WORTH A CHECK-IN. Goals: the dashboard, beside the
  close-and-plan card, the month's orders and PAST MONTHS. Team: EVERYONE,
  beside the summary and WORTH A CHECK-IN. Planning and closing are one
  centred 624px column.
- **List + detail** on Contacts: 440px list column with a right hairline, then a
  752px detail pane split by the same layout: next step and history, beside
  a 340px column for what they are aiming for and what you know. Selecting a row updates the
  pane; no navigation happens.
- **Density up, not size up**: rows keep their height but the chip moves to a
  fixed right column so names align; the sidebar item is 44px where the mobile nav
  item is 64.
- **Hover** exists and is meaningful: rows and sidebar items wash with
  `primary/muted`, buttons darken to `primary/hover`. Hover never reveals the only
  path to an action.
- **Keyboard**: `/` or `Cmd/Ctrl+K` focuses search, `↑/↓` moves the list
  selection, `Enter` opens, `Esc` closes a dialog or clears search. Focus-visible
  is a 2px `state/focus` ring with 2px offset, on every focusable element.
- Max content width 1440; beyond that the space stays empty after the
  content rather than adding a third column — a third column would need a third thing worth showing, and there
  isn't one.

---

## What adapts and what does not

**Adapts:** number of columns, navigation pattern, row density, dialog vs. sheet,
hover and keyboard affordances, scroll physics, share and file pickers.

**Does not adapt:** colour, type scale, radii, icon set, spacing scale, component
anatomy, copy. A screen must be recognisably the same screen on a phone and on a
laptop.

---

## Implementation notes

- One widget tree per screen, branching on `context.screenSize` — not two screens
  with duplicated logic.
- Layout choices live in the screen, never in a component: `ContactRow` does not
  know which platform it is on; the screen decides the column count.
- Providers and domain logic are size-class agnostic. If a provider needs to know
  the layout, the layout decision is in the wrong place.
- Test each screen at 390, 744 and 1440 as a matter of course; a widget test per
  screen at the mobile width is the minimum bar.
