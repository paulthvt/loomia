# Event type colours — design

Date: 2026-11-19. Issue: [#516](https://github.com/paulthvt/loomia/issues/516).
Mockups: FigCraft `Loomia.figcraft`, page "08 — Horizon (proposal)", section
"Event colours — #516".

## Why

The issue: in the calendar's time views the events all look alike and lack
contrast ("manque de contraste, peut-être mettre une couleur par type
d'événement"). The screenshot is the phone's 3 days view, every event done,
so every block wears the done look: white, hairline, muted text, no bar.

Each event type gets a colour, and events show it wherever they are drawn,
so the kind of event reads before its title. Past events keep their colour,
quieter.

## Goals

1. Every event type has a colour from the tag palette, set in the event type
   editor. A new type gets one without the user picking.
2. Events show their type's colour in every list and grid, on Today too.
3. Past events stay recognisable by type, and their text is no harder to
   read than today.

Non-goals: a colour per event; colours for tasks; a colour legend; filtering
the calendar by type.

Anti-goals: red anywhere (principle #4: red is for errors and destructive
actions); a screen full of tinted cards (palette rule #2: one tinted pair per
screen); fading text below its current contrast.

## Approaches

| Approach | Trade-off | |
| --- | --- | --- |
| Reuse the tag palette: `event_workflow.color public.tag_color` | Reuses the palette, its light/dark pairs, the swatch picker and `nextTagColor`. Types and tags share 8 colours. | **Chosen** |
| A separate event palette | Free to diverge, but duplicate tokens, picker and translations for no present need. | |
| A free hex colour per type | Breaks dark mode and contrast, lets red in. | |

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Colour per what? | Per event type (`event_workflow`). | The ask; one place to set it. |
| Which colours? | The 8 `TagColor` keys, `container` and `ink` per mode. | Already tuned for contrast in both modes, no red. |
| A new type's colour | The first key no other type uses; all used, the first. Like tags. | Nobody has to pick; types differ by default. |
| Existing types | The migration colours them in creation order, per owner, the same rule. | No grey types after the update. |
| Events with no type | Today's orange (`primary` / `primaryContainer`). | Not in the palette, so "no type" stands apart. |
| Grid blocks (phone 3 days and week, desktop week) | Upcoming: the type's `container` fill, a 3 dp start bar in `ink`, text `onSurface`. | Small blocks: the fill is what the eye scans. |
| Lists (Today, calendar day list, desktop day popover) | The white card stays; only the bar takes the type's `ink`. | Palette rule #2; tinted cards would compete with the hero. Paul chose A over tinted cards (mockup 4). |
| Past events | Keep the over look (#451): no fill, hairline, text a step lighter. The bar keeps the type's `ink` at 50 % opacity. | Type stays readable; "past" is said by the missing fill. |
| Past text on the grid | `onSurfaceVariant` for the title, as the lists' over look, instead of `textMuted`. | The contrast complaint. |
| When is a grid block quiet? | When it is over (the lists' rule: ended, or started if it has no end), and also when done. Today it is only when done. | One rule everywhere; a past event looked current until ticked. |
| Month grid | Dots stay white (decided while planning). | They only ever draw on the hero gradient, where a 6 dp dot in a type colour fails 3:1 in both modes; mockup 5 was drawn on white by mistake. |
| Desktop month chips | The chip's bar takes the type's `ink`, faded when over. | Same as lists. |
| Event page | Unchanged (decided while planning). | It shows no type line to put a dot before. |
| Picker | The tag editor's swatch row (32 dp circles, ringed and checked when picked), under the name in the event type editor. | Reuse. |

## Behaviour

### Data

One migration, additive, safe for the released app:

- `alter table public.event_workflow add column color public.tag_color`,
  backfilled per owner in `created_at` order with the first-unused rule.
  It stays nullable: the migration guard counts `set not null` as a
  tighter column. The backfill and the trigger leave no null; Dart reads
  one as stone.
- A `before insert` trigger fills `color` when it is null, with the same
  rule. The released app and the `seed_workflows` defaults insert without a
  colour and still get one. The table already has table-level grants to
  `authenticated`; no grant change.

No Edge Function changes.

### App

- `EventWorkflow` gains `final TagColor color`; the repository reads it and
  gets `setColor(id, color)`. `create` sends no colour: the trigger picks
  it. The first-unused rule is `TagColor.firstFree`, which `nextTagColor`
  now calls; the test fake mirrors the trigger with it.
- The event query embeds `event_workflow(color)`, so `CalendarEvent.color`
  reaches every widget without the type list; editing a type already
  reloads the events.
- One resolver turns an event into its two colours: its type's `TagInk`, or
  the primary pair for no type or a type not loaded yet. Every surface below
  reads it, so the rule lives once.
- Surfaces: `EventRow` (Today, calendar day list, desktop day popover),
  `_WeekCard` (desktop week, phone 3 days and week) and `MonthEventChip`.
- Screen readers: no change; the colour adds nothing a label must say.

### Tests

- Unit: the first-unused rule over type colours; the resolver (type, no
  type, unknown type).
- Widget: a list row's bar takes the type's ink and is faded when over; a
  grid block's fill is the type's container upcoming and none when over;
  a month chip's bar is faded when over.
- Database: `schema_rls_test.sql` still passes; a test that an insert with
  no colour gets the first unused one.
- Goldens: previews with typed events change; regenerated through CI.

## Left to the builder

The exact sample events used in previews; how the resolver is named and
where it lives (next to `CalendarEvent` or `EventWorkflow`); the swatch row's
reuse shape (lift `_Swatch` into `lib/core/ui/` or share it from tags).
