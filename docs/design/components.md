# Component library — v1

24 components, built in Figma on page `Components`, every fill / stroke / padding
/ radius bound to a `Loomia/color` or `Loomia/scale` variable.

Implemented in Flutter so far, in `lib/core/ui/` — Avatar (+ AvatarGroup), Chip,
ProgressBar, SectionHeader, EmptyState, ActivityItem, StatTile, GoalCard,
ActionItem (+ DateChip), TopBar. They are visible in `flutter widget-preview
start`, group **Components**. The rest still exist in Figma only; navigation
chrome waits for a second destination.

Conventions used below: **variants** are Figma variant axes; **props** are text /
boolean / swap properties; **states** describe behaviour that the implementation
must cover even where the library ships only the default (hover and focus are
pointer/keyboard-only and therefore desktop-only).

Every interactive component has a ≥44px touch target on mobile, regardless of its
visual size.

---

## Atoms

### 1. Icon
Placeholder slot, 20×20, used as an `INSTANCE_SWAP` target. Production glyphs come
from Material Symbols Rounded in Flutter, so the library ships one slot instead of
200 vectors.

### 2. Button
*Purpose:* commit an action.
*Anatomy:* pill container · optional 20px icon · `label-lg` text.
*Variants:* `Tone` = Primary | Tonal | Text × `State` = Default | Hover | Disabled (9).
*Props:* `label` (text), `showIcon` (bool).
*States:* pressed = `primary/hover` at 120ms; focus-visible = 2px `state/focus`
ring offset 2; loading = label swaps for an indeterminate 16px spinner, width held.
*Responsive:* height 44 everywhere (a pointer does not need less, and 44 keeps one
spec); full-width on mobile only when it is the single action in a sheet.
*Rules:* one Primary per screen region. Destructive actions use Primary with
`semantic/error` fill — nothing else in the product does.

### 3. IconButton
*Purpose:* a secondary affordance that does not deserve words.
*Anatomy:* 44×44 pill hit area · 20px glyph.
*Variants:* `Tone` = Ghost | Tonal × `State` = Default | Hover (4).
*States:* hover = `primary/muted` wash and `primary/text` glyph; focus-visible ring.
*Rules:* always has an accessible label. Never the only way to reach an action on
mobile.

### 4. Avatar
*Purpose:* a person.
*Anatomy:* circle · `primary/container` fill · initials in Bold, tracked +2%; an
image paint replaces the fill for a photo, initials stay underneath as fallback.
*Variants:* `Size` = 24 | 32 | 40 | 56.
*Props:* `initials` (text).
*Responsive:* 40 in mobile rows, 32 in desktop dense rows and stacks, 56 on a
contact header (both platforms), 24 inline in a sentence.
*Rules:* circular at every size. Initials, never a generic person glyph
(principle #2).

### 5. AvatarGroup
*Purpose:* "a group of people" as one object.
*Anatomy:* up to 3 × Avatar 32 overlapped −10px with a 2px `surface/default`
ring · overflow count pill (`+4`) on `surface/sunken`.
*Rules:* team contexts only. Never on a row about one person.

### 6. Chip
*Purpose:* a fact about a person — never a judgement.
*Anatomy:* radius-8 tinted container · optional 14px glyph · `caption` Medium.
*Variants:* `Tone` = Neutral | Primary | Secondary | Accent.
*Props:* `label` (text), `showIcon` (bool).
*Rules:* Neutral = taxonomy (Customer, Team); Primary = relationship state;
Secondary = pace; **Accent = anchored to a real date only** (birthday, promised
call-back). No red chip exists. Chips are not filters unless they are in a filter
row — filters use Primary for the active one.

### 7. ProgressBar
*Purpose:* pace, not score.
*Anatomy:* 8px pill track · pill bar · caption row (`pace` left, `time left`
right).
*Variants:* `Tone` = Primary | Secondary.
*Rules:* Secondary is the default (`secondary/base` on its own track). Primary tone exists
only inside the hero. The caption says how much time is left, never a verdict.

### 8. TextField
*Purpose:* enter or edit one value.
*Anatomy:* `label` above (13px Bold) · 48px box, radius 12, 1px hairline ·
optional trailing icon · helper text slot always rendered so layout never jumps.
*Variants:* `State` = Default | Focus | Error | Disabled.
*Props:* `label`, `value`, `showHelper`, `showTrailingIcon`.
*Rules:* no floating labels — they move, and movement costs legibility across a
25–65 age range. Error is the only non-destructive use of red in the product.

### 9. SearchField
*Purpose:* find a person.
*Anatomy:* sunken pill, no border · leading glyph · placeholder.
*Responsive:* mobile — full width, sticky under the app bar; desktop — fixed 320
in the top bar, focusable with `/` and `Cmd/Ctrl+K`.

### 10. SectionHeader
*Purpose:* the only structural divider in the product.
*Anatomy:* `overline` title in `text/muted` · optional trailing text action or
count.
*Props:* `title`, `actionLabel`, `showAction`.
*Rules:* no rules, no card headers, no chevrons. Space and this header do all the
grouping (principle #6).

---

## Molecules

### 11. TodayHero
*Purpose:* answer "what should I do today?" from arm's length.
*Anatomy:* radius-20 `primary/base` block · `TODAY` eyebrow · one **sentence**
(not a number) in `title-lg` · white progress bar on a `primary/hover` track ·
footer: progress left, effort in minutes right.
*Props:* `eyebrow`, `headline`, `progressLabel`, `effortLabel`.
*Responsive:* mobile full width; desktop the width of the left column, headline
steps to `headline` (24px).
*Rules:* the **only** filled colour block in the product (guardrail #1). The count
lives inside the sentence so it cannot read as a quota. Footer states effort in
minutes, never a percentage of a target.

### 12. ActionItem
*Purpose:* the unit of Today — a suggestion, not a task.
*Anatomy:* radius-16 card, 1px hairline · Avatar 40 · name (`title`) · reason
(`body-sm`) · optional chip · trailing resolve ring (28px empty ring with a faint
check, 48px touch target; a bare check read as a status, not a button — #190).
*Props:* `name`, `reason`, `showMeta` (+ nested avatar initials and chip label).
*States:* pressed = whole row opens the contact; the ring resolves in one tap and
stays filled (primary, white check) while the tick saves; resolving collapses the
row over 240ms.
*Rules:* max ~5 on Today (principle #3). The reason is mandatory — it is what
makes the item an offer instead of a demand (principle #4).

### 13. ContactRow
*Purpose:* a person in a list.
*Anatomy:* no card, no border · Avatar 40 · name (`title`) · subtitle = last real
contact · optional taxonomy chip.
*Props:* `name`, `subtitle`, `showChip`.
*States:* hover / selected = `primary/muted` wash at radius 12; keyboard
selection moves with ↑/↓ on desktop.
*Responsive:* 64px min height on mobile; desktop rows are the same height but the
chip moves to a fixed right column so names align.
*Rules:* the subtitle is what happened, never a field count or completion meter.

### 14. ActivityItem
*Purpose:* one thing that happened.
*Anatomy:* 8px dot on a 2px hairline rail · title (`body`) · meta
(`caption`, date · kind).
*Props:* `title`, `meta`, `showRailLine` (off on the last item).
*Rules:* chronological, collapsed to the last 3 with "All 24" to expand. Reads as
memory, not as an audit log — no edit metadata, no author.

### 15. TaskItem
*Purpose:* something the user wrote down themselves (vs. an ActionItem, which Loomia
suggested).
*Anatomy:* 22px circular checkbox · `body-lg` label.
*Variants:* `State` = Open | Done.
*Rules:* Done = filled circle plus muted ink, **no strikethrough and no counter** —
a kept commitment should look settled, not crossed out. Row collapses 240ms after
completion.

### 16. StatTile
*Purpose:* a count plus the reason it matters.
*Anatomy:* radius-16 tile · `overline` label · `numeric-lg` value · `caption` note.
*Variants:* `Tone` = Plain | Primary | Secondary.
*Props:* `label`, `value`, `note`, `showNote`.
*Responsive:* two-up on mobile, four-up on desktop.
*Rules:* one tinted pair per screen maximum. The note frames the number against
the user's own intent ("of 40 you aimed for"), never against other people.

### 17. GoalCard
*Purpose:* own intent vs. own progress.
*Anatomy:* card · title + pace label · `numeric` value + target in muted ink ·
ProgressBar (Secondary).
*Props:* `title`, `value`, `target`, `pace`.
*Rules:* pace is `secondary/text` when behind, muted when on pace, **never red**
(principle #5). Tabular figures so the number does not shift as it updates.

### 18. EmptyState
*Purpose:* tell the user that empty is fine.
*Anatomy:* 56px tinted circle with one geometric glyph · `title-lg` · `body` ·
optional Tonal button.
*Props:* `title`, `body`, `showAction`.
*Rules:* copy says "you are up to date", never "no data". No illustration —
illustrations age, and childish ones are off-brief.

### 19. ConfirmDialog
*Purpose:* stop before something irreversible.
*Anatomy:* radius-20 `surface/raised` · `elevation/overlay` · title · body ·
actions right-aligned: Text (safe) then Primary filled with `semantic/error`.
*Props:* `title`, `body`.
*Responsive:* desktop = centred 352–480 dialog with a 40% scrim; mobile = bottom
sheet, identical internals, the two actions side by side sharing the width. The
same frame carries short forms (Add someone, Log something, Change stage): their
fields scroll when the keyboard is up, the title and the actions stay.
*Rules:* the only component with a red fill. The safe action sits left so the
destructive one is never the accidental tap. Escape / tapping the scrim cancels.

---

## Navigation

### 20. NavItem
Bottom-bar destination. Active = `primary/container` pill behind the glyph plus a
Bold `caption` label. `label` prop. **No badge counts, ever** (principle #4).
Labels always visible.

### 21. BottomNav
Four destinations (Today, Contacts, Team, Goals) on `surface/default` with a 1px
top hairline and no shadow. Mobile only. Platform adds the safe-area inset below
it.

### 22. SidebarItem
Desktop destination. 44px tall (a pointer is precise), radius 12, active =
`primary/container`. Hover = `primary/muted`; focus-visible = 2px `state/focus`.

### 23. Sidebar
248px fixed rail on `surface/sunken` with a right hairline: wordmark, the four
destinations, account block pinned to the bottom. Collapses to 72px icon-only
below 1100px, and is replaced by BottomNav below 840px.

### 24. TopAppBar
`surface/canvas`, no shadow and no border until content scrolls under it (then a
hairline appears). `overline` eyebrow carries the date, `headline` title carries
the place; the title collapses to `title-lg` on scroll. One trailing ghost action.

---

## Deliberately absent from v1

Tabs, date picker, snackbar, tooltip, menu, switch, radio group, stepper, table,
chart, FAB, badge, carousel, onboarding.

Each is absent for the same reason: no screen in this phase needs it, and
principle #1 plus the working rules in CLAUDE.md say not to scaffold for later.
Badges and charts additionally need a product argument before they get a
component — a badge count contradicts principle #4, and a chart is one step from
the performance dashboard this product is not.
