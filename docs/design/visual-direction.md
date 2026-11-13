# Visual direction — three explorations

Status: **locked** (2026-09-22) — Direction B, palette **N1 Forest → Olive**, replaced 2026-09-30 by the
Loomia palette **L1 Ocre pale** (design-system.md §1),
circular avatars, light and dark fully specified. The built system lives in
[design-system.md](design-system.md), [components.md](components.md),
[responsive-design.md](responsive-design.md) and [screens.md](screens.md). This
document is kept as the record of what was explored and why B/N1 won.

Nothing is implemented in `lib/` yet; the placeholder seed theme in
`lib/app/theme/` stays until the first feature needs the real one.

Figma: [Loomia](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia) → page
`01 — Direction exploration`. Each direction has a palette block, a type
specimen, and one Today screen at 390px. Same content in all three, so the only
variable is the visual language.

Judge them against [design-principles.md](design-principles.md), especially
#4 (suggest, never nag), #5 (progress without pressure) and #6 (structure from
space and type).

---

## Direction A — Warm Productivity

Paper-warm and quietly organised. A well-kept notebook.

**Colour.** Warm off-white canvas `#FAF8F4`, pure white surfaces, warm near-black
ink `#221F1B`. Primary a muted sage `#52755C` with a soft container `#E4EBE3`;
secondary terracotta `#C0714F` / `#F6E6DC` for time-sensitive human moments
(birthdays, promises). Semantics desaturated to match: success `#3F7A5E`, warning
`#B8811F`, error `#B3462F`. Colour is used at ~5% of surface area — almost
everything is paper, ink, and one hairline.

**Typography.** One humanist geometric sans (DM Sans) across the whole ramp;
Bold for greetings and numbers, Medium for names and labels, Regular for body.
Wide, open apertures read well at 13–15px on Android and Web. Tabular figures
for goal numbers.

**Shape.** Radii 16 for cards, 8 for inputs, pill for chips and buttons, circular
avatars. Rounded but not soft-toy — corners stay tighter than the container's
padding, so nothing looks inflated.

**Components.** Bordered white cards on warm paper: 1px `#E8E3DA` hairline, zero
shadow. Cards separate content rather than float above it. Chips are tinted
containers with no border. Filled primary button, tonal secondary, text tertiary.

**Dashboard mood.** Grouped list: greeting + date, a one-line progress bar,
"Priority" (3 cards), goal, one team nudge. Calm, scannable, obviously a to-do
day rather than a database.

**Strengths.** Widest demographic appeal — reads neutral for men and women, 25 to
65. Zero MLM smell. Lowest contrast fatigue for an app opened many times a day.
Maps cleanly onto Material 3 component behaviour without looking like Material.
Cheapest to make accessible (all pairs clear AA).

**Risks.** Sage-and-terracotta on off-white is the most-copied palette of the last
three years — memorability comes from almost nothing here, so the identity leans
entirely on logo and a few signature moves. Bordered cards everywhere can drift
into blandness. In dark mode the warmth is easy to lose to muddy grey-green.

---

## Direction B — Fresh & Energetic

Confident and momentum-forward, still sophisticated.

**Colour.** Cool near-white `#FBFBFC` and white surfaces, deep teal-green
primary `#0E6E63` used in *large filled blocks*, marigold secondary `#F2A43A` for
progress and goals, coral accent `#E9614C` for time-sensitive items. Ink
`#12211F`. Colour is a structural material here (~20–25% of surface), not a trim.

**Typography.** Plus Jakarta Sans throughout, run harder: Bold at display sizes,
Bold small-caps-style tracked labels (`FRIDAY 19 SEPTEMBER`, `CUSTOMERS`),
Regular body. More weight contrast, larger headings, tighter leading than A.

**Shape.** Radii 22 for the hero, 18 for tiles, 14 for avatar squircles, 10 for
chips. Squircle avatars instead of circles — a deliberate signature that reads
"product", not "social network".

**Components.** Colour-forward tiles. One filled hero block carries today's
progress in white-on-teal; below it bordered white rows; a two-up tinted stat
pair for goal and follow-up count. Solid pill buttons, bold chips, thicker (8px)
progress tracks.

**Dashboard mood.** A morning briefing. The eye lands on the filled hero first,
then priorities, then the numbers. Highest perceived energy of the three.

**Strengths.** Most legible priority signalling on a small screen — the hero
answers the core question in one glance from arm's length. Most memorable of the
three at thumbnail size. Motivating for daily reopening. Tinted stat tiles scale
well into desktop multi-column.

**Risks.** Closest of the three to the thing we must not be: filled colour blocks
plus bold numerals plus marigold progress is one step from a sales dashboard, and
principle #5 is easy to break here. Colour-coded status can read as pressure.
Teal drifts to generic SaaS blue if it loses its green; marigold on white is the
weakest contrast pair and needs careful text-colour rules. Dark mode requires a
second, retuned set of tints rather than simple inversion.

---

## Direction C — Quiet Luxury

Editorial, restrained, printed. A daily agenda page rather than an app screen.

**Colour.** Bone paper `#F5F2EC`, barely-there surface `#FBFAF7`, near-black ink
`#1A1917`. **One** accent: deep olive `#3E4A35`, used in 7px marks, 2px rules and
numerals. Clay `#8C5A3E` for the single action word on each row. Semantics exist
but are desaturated almost to ink. Near-monochrome by intent.

**Typography.** The identity *is* the typography. Fraunces (a warm, slightly
quirky serif) for every proper noun and headline; Inter for body and for tracked
uppercase micro-labels at 10px (`PRIORITY`, `SEPTEMBER GOAL`). Names in serif is
the whole idea: it makes people feel like people, not records — principle #2,
expressed as type.

**Shape.** Radii 4–8, and almost nothing to apply them to. Structure comes from
1px hairline rules between rows; cards are removed entirely. Circular avatars,
36px, tinted, used sparingly.

**Components.** Rule-separated list rows. Text-only actions in clay at the row
end. Ghost buttons. Progress as five dots or a 2px rule. Text-label bottom
navigation with a 2px active underline. Roughly half the node count of A or B.

**Dashboard mood.** Reads as a printed page: masthead, rule, today's count,
rule, three named rows, rule, a goal line. Slowest, quietest, most premium.

**Strengths.** By far the most distinctive and the only one nobody will mistake
for a template. Ages well — no trend to date it. Structurally incapable of
looking like an MLM tool. Removing cards removes the "database to maintain"
feeling better than any other option (principle #3). Least code, least chrome.

**Risks.** Weakest affordances — text-only actions and hairline nav are less
obvious for less tech-confident users, and independent distributors are a wide
skill range. 10px tracked labels and serif at small sizes are a real legibility
and localisation risk (accents, long German/Portuguese strings, Android font
rendering). Touch targets need padding that the airy look fights. Can read cold
or slow for a tool meant to be used in 90 seconds between appointments. Serif
adds a webfont on Web (FOUT, extra weight).

---

## Comparison

| | A — Warm Productivity | B — Fresh & Energetic | C — Quiet Luxury |
| --- | --- | --- | --- |
| Distinctiveness | low-medium | medium-high | **high** |
| "Not an MLM tool" | high | medium | **highest** |
| Priority legibility at a glance | medium-high | **high** | medium |
| Demographic range (25–65, all genders) | **widest** | medium | medium |
| Accessibility effort | **lowest** | highest | medium |
| Dark mode difficulty | medium | **highest** | low |
| Flutter implementation cost | **lowest** | medium | medium (fonts) |
| Risk of reading as pressure | low | **high** | lowest |

---

## Recommendation — A, with C's typographic discipline

**Pick Direction A as the system, and steal three specific moves from C.**

Reasoning, in principle order:

- Principles #4 and #5 (suggest, never nag / progress without pressure) are the
  ones this product cannot get wrong, and they are structural, not cosmetic. B
  fights them: filled colour blocks and bold numerals *mean* urgency whatever the
  copy says. A and C are both safe; A is safer to extend by a future contributor
  who reaches for a colour.
- Principle #2 (people before records) and the wide age range point at A's
  legibility over C's 10px tracked labels and serif body.
- A is the only direction that stays coherent when a screen gets dense —
  Contacts with 400 people, a desktop three-column layout, a filter bar. C's
  rule-only structure loses its calm under density; B's colour blocks get loud.

A's single real weakness is memorability, and that is exactly what C fixes
cheaply:

1. **Serif display, sans everything else.** Fraunces SemiBold for the greeting,
   contact names on detail screens, and goal numerals. DM Sans for all body, UI,
   and labels. One borrowed move, most of C's distinctiveness, none of its
   legibility cost.
2. **Rules instead of cards inside a list.** Keep A's bordered card as the
   *section* container, but separate items within it by hairlines rather than
   giving each item its own card. Kills the floating-card look forbidden by
   principle #6.
3. **Tracked uppercase micro-labels** for section headers (`PRIORITY`,
   `THIS WEEK`) — at 11px Medium, not 10px, and in muted ink.

And drop one thing from A: the terracotta secondary stays strictly for
human-moment items (birthdays, a promised call-back). It is never a button, never
a status, never a chart colour. That restraint is what keeps warm from becoming
salesy.

If you'd rather not hybridise: **A alone** is the safe answer and **C alone** is
the ambitious one. B is the one I'd argue against — it is well-suited to a sales
performance app, which is the product we are explicitly not building.

---

## Decision: Direction B

B was chosen for its glance-legibility and memorability. The argument above
stands, so B carries guardrails that are part of the system, not suggestions:

1. **One filled block per screen.** The hero on Today is the only large filled
   colour surface. No second filled block, ever. Everything below it is a white
   (or dark-surface) bordered row.
2. **Accent is for dates, not for judgement.** The accent colour marks things
   anchored to a real moment — a birthday, a promised call-back, a commitment
   made. Behind-pace, overdue, and "no contact in 30 days" use the *secondary*
   or plain muted ink. Never the accent, never red.
3. **Error red is destructive-only.** Delete, permission failure, sync failure.
   Never a status.
4. **Numbers get one weight, not a size war.** Goal numerals top out at 26px on
   mobile. No hero numbers larger than the greeting.
5. **No comparative framing anywhere.** No ranking, no "vs last month" unless the
   user asks for it in a detail view, no percentile language.

If a screen ever reads as a performance dashboard, one of these five was broken.

---

## Direction B — palette combinations

Figma page `02 — B palette combinations`. Four combinations, each rendered as the
same condensed Today screen in **light and dark**, plus the palette swatches.
Structure, type and radii are identical across all four — only hue changes.

### B1 — Teal & Marigold
`#0E6E63` primary · `#F2A43A` secondary · `#E9614C` accent on `#FBFBFC`

The baseline. Highest energy, most familiar. Marigold-on-teal is a strong,
legible progress signal. Risk: teal is one desaturation step from generic SaaS
blue-green, and teal + coral + marigold is the most "startup" of the four.

### B2 — Forest & Apricot
`#1F5F45` primary · `#EE9A63` secondary · `#B5556A` accent on `#FCFBF9`

Same structure, warmer temperature. The forest primary is heavier and calmer than
teal; apricot is softer than marigold; the rose accent reads human rather than
alarming. Lowest "sales dashboard" risk of the four while keeping B's energy.
Slightly less contrast punch on the hero.

### B3 — Petrol & Lime-olive
`#15586B` primary · `#9CB338` secondary · `#D9713F` accent on `#FAFBFB`

Coolest and most instrument-like. Petrol blue-green reads precise and technical;
the olive-lime progress colour is unusual and memorable. Risk: coolest option, so
the warmth in the brief is carried entirely by the terracotta accent — and it
edges toward "analytics tool".

### B4 — Aubergine & Amber
`#58355C` primary · `#E8A33D` secondary · `#2F7C74` accent on `#FCFBFC`

Most distinctive. Nothing in this category uses aubergine, so it is instantly
identifiable and it is the strongest dark-mode performer (the filled hero holds
up on near-black better than any green). Amber-on-aubergine is a genuinely
premium pairing. Risks: purple carries more cultural baggage than green, and it
needs care to avoid reading either beauty-industry or crypto; the accent teal has
to stay strictly accent or the palette gets busy.

### Dark theme notes (all four)

Dark is not an inversion. Rules applied in the mocks:

- Canvas is a hue-tinted near-black (e.g. `#0C1413`), never `#000000`; surfaces
  step up one level (`#141E1C`), borders are a third step (`#25322F`).
- The hero keeps the *same* primary as light mode — it is a filled block on a
  dark canvas, so it stays readable and the brand colour is not diluted.
- Primary and accent used as *text or icon* colour switch to lighter tints
  (e.g. `#0E6E63` → `#57C6B3`); the saturated light-mode values fail contrast on
  dark surfaces.
- Tinted containers become deep, low-saturation versions of their hue
  (`#FDEBCF` → `#33280F`) with a light tint for the text on them.

### Avatar shape

Figma page `02`, block `Avatar shape — circular vs squircle`. Same contact rows,
size ramp (24/32/42/56/72), overlap group and photo crop under both rules.

- **Circular** (radius 999) — reads unmistakably as a person, works at 24px,
  familiar everywhere. Overlap groups look cleaner. Least distinctive.
- **Squircle** (radius ≈ 34% of size, so it scales) — a deliberate signature,
  reads more "product" than "social network", pairs better with the 16–20px card
  radii. Weaker at 24px, and photo crops lose a little face at the corners.

Whichever wins, the rule is: **one shape for every avatar in the product**,
including team members, group stacks and photo avatars.

**Decided: circular, radius 999 at every size** (2026-09-22).

---

## Direction B — analogous palette options

Figma page `03 — Analogous palettes (circular avatars)`. Four options where
**primary and secondary are neighbours on the colour wheel**, separated by
lightness and saturation rather than hue. This is deliberately not how Material
generates a scheme — M3 derives secondary/tertiary by rotating hue away from the
seed, which is exactly the spread we're avoiding here.

Why analogous works for this product: a single hue arc reads as one deliberate
brand rather than a set of status colours, and it structurally prevents the
"colour-coded urgency" failure mode that Direction B risks. The cost is less
contrast between primary and secondary, so the palettes buy it back with
lightness steps (dark primary block, bright secondary bar).

All four keep B's structure, radii, type and the five guardrails above, and all
four are shown in light and dark with circular avatars.

### N1 — Forest → Olive **(chosen)**
`#235C46` primary · `#6F9339` secondary · `#B08B2A` accent on `#FBFBF8`

Green arc, one step warmer at each stop. Olive-lime progress on deep forest is the
clearest signal of the four analogous options. Warm, outdoorsy, calm; the closest
to the original brief without landing on the over-used sage.

### N2 — Petrol → Teal
`#15586B` primary · `#2E8B84` secondary · `#57B0A6` accent on `#FAFBFB`

Single blue-green family at three lightnesses — the most cohesive and the calmest.
Everything looks like one material. Weakness: the whole product is cool, so warmth
has to come from photography and copy, and primary/secondary can read as the same
colour at a glance on a small screen.

### N3 — Aubergine → Plum
`#58355C` primary · `#A0407A` secondary · `#D9788C` accent on `#FCFBFC`

Purple arc into magenta and rose. Most distinctive; strongest dark mode. The arc
is what keeps it coherent — aubergine with an unrelated accent would read busy,
aubergine with plum reads intentional. Risk: the magenta/rose end skews more
feminine than the brief allows, which argues for using it sparingly.

### N4 — Clay → Amber
`#8E4429` primary · `#C8762C` secondary · `#DFA83C` accent on `#FCFAF7`

Fully warm arc, no cool colour anywhere in the product. Earthy and human, and the
furthest of any option from CRM or enterprise software. Risk: burnt clay is close
to the colour conventions for warning/error, so semantic warning and error need
explicit separation (error stays a distinctly cooler red, warning becomes a
neutral-ink treatment rather than amber).

### Changing the palette later

Cheap, provided the palette is never written as a literal:

- **Figma:** one variable collection `Loomia/color` with `Light` and `Dark` modes.
  Every fill, stroke and text colour in every component and screen binds to a
  semantic variable (`surface`, `primary`, `on-primary`, `primary-container`,
  `secondary`, `accent`, `border`, `text-primary`, …). A palette swap then means
  editing ~24 values in the variables panel; components and screens update
  everywhere. Switching *modes* is a dropdown on any frame.
- **Flutter:** the same names in `lib/app/theme/app_colors.dart` as two
  `ColorScheme`s plus a small extension for tokens `ColorScheme` doesn't cover.
  Widgets read `Theme.of(context)` only, so a swap is one file.

What is *not* cheap to change later: the token **names and structure**, the
lightness relationships the layouts rely on (dark primary block + bright
secondary bar), and the number of accents. Those are the real commitment — hue is
a value.

The mocks on pages `01`–`03` are exploration and use literal hex. Only the chosen
palette gets built as variables; the exploration pages stay as-is for reference.

---

## Horizon — 2026 restyle

**Status:** shipped (2026-11-13, #499). Visual reference: `docs/design/horizon/`, spec: `docs/superpowers/specs/2026-11-13-horizon-theme.md`.

Direction B's "one filled block" rule worked but felt rigid. Horizon refines it into a **gradient hero** that feels warmer, more grounded, and unmistakably Loomia. The system stays otherwise unchanged: same spacing, same radii, same components — this is a palette and chrome restyle, not a redesign.

### What changed

- **Hero gradient:** rosewood `#82424F` → apricot `#E39A68` at 135° (dark: `#4F2530` → `#A8623F`). One gradient hero per screen, replacing the old primary-filled TodayHero. The hero holds what matters now: date and greeting on Today, month grid on Calendar, search and filters on Contacts, your own volume on Goals, back and title on detail screens.
- **Hero components:** `HeroPanel` (band/screenTop), `HeroCard`, `HeroIconButton`, `HeroFormList`, `DetailHero`, `HeroLine`, `HeroBadge`, `HeroEyebrow`. Text is white with a quiet variant at 85%; translucent fills at 18% (buttons), 12% (inputs, switches).
- **Cards:** white with one soft shadow (`0 2 8 @7%`), no border. Radius 24 standard, 28 hero card, 32 hero bottom corners. `SettingsGroup` became a card.
- **Section headers:** title case, 18 bold ("People", "Tasks"), no overline. The overline token stays for stat tiles and date eyebrows only.
- **Phone navigation:** floating dark pill bar (`#2A181C`) on the four tabs, sliding amber pill (420 ms emphasized), white **+** for creating (task / event / person / own order per tab). Detail screens: back in the hero, no bar. Replaces "Add a task", Calendar FAB, add-person button, "Log my own order".
- **Desktop/tablet:** floating dark sidebar, first item the labelled create button (New task / New event / New person / Log my own order); rail shows a **+** circle.
- **Today all-done:** gradient check badge, static confetti (hidden from screen readers), "You're all done for today", warm line. No streaks, no scores.
- **Canvas:** `#F6F2ED` light, `#120F0C` dark (unchanged).

### New tokens (LoomiaColors)

`heroGradient`, `onHero`, `onHeroQuiet`, `heroFill`, `heroFillSubtle`, `onHeroFill`, `heroCardShadow`, `heroCardBorder`, `chrome`, `onChrome`, `onChromeMuted`, `chromeBorder`; `AppRadii.card` (24), `heroCard` (28), `hero` (32).

### Why it works

1. The gradient is a **structural element**, not decoration. It frames what you're here to do, and everything else sits on quiet white — the calm/momentum balance Direction B aimed for, now without the salesy risk of a solid fill.
2. One hero per screen keeps it a signal, never wallpaper.
3. The warm rosewood → apricot arc reads grounded and human — no teal, no startup blue-green.
4. The floating chrome (bar, sidebar) is dark in both modes, so switching themes feels like adjusting brightness, not swapping identities.

This is the final restyle before shipping. Future palette changes stay cheap (one Figma variables panel, one Dart file), but the gradient structure is now load-bearing.


