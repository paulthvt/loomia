# Today, all done on desktop — the band is the moment

Issue: #518. Mockups: `docs/design/horizon/today_all_done_desktop_light.png`
and `today_all_done_desktop_dark.png`, exported from `Loomia.figcraft`, page
"08 — Horizon (proposal)", section "Today, all done — desktop options",
frames *A · The band is the moment* (58033) and *A · dark* (58657). Options B
and C sit beside A and are not built. Builds on the Horizon theme
(`2026-11-13-horizon-theme.md`, #499) and follows Goals desktop (#507/#508).
For looks the PNGs win; for behaviour this text wins.

## Intent

On a desktop window, once everything on Today is ticked, the band shows a
small greeting on the far left and the white all-done card on the far right,
with nothing in between. Below it, the main column has only an empty "Tasks"
header, and Catch up, the one thing left to do, sits in the narrow side
column. Goals had the same empty band and was fixed by letting the band carry
the content itself (#508). Today does the same: the band holds the moment,
and the main column opens with what is still worth doing.

Phone and tablet don't change.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Which option | A: the band is the moment | Paul's choice, 2026-11-15. It reuses the Goals A pattern. |
| White card | Gone on desktop in the done state. The band holds the greeting, then the all-done block, and the art on the right. | Fills the band, the same way #508 did for Goals. |
| All-done block | Headline, warm line, a full bar, and "N of N done" under the bar. All of it sits in a hero inset panel (`AppTheme.heroInset`), as wide as the greeting column and at most 520 px. | White 15 px text straight on the gradient falls under 4.5:1 past roughly a third of the band's width (about 3.9:1 where the warm line ends, at 1440 and 1200 px windows). The inset is the dark glass that Goals' pace panel uses, already tested at 4.5:1 over the gradient's light end. *(Ruled while specifying: the first mockup had the text bare on the gradient.)* |
| Ink | Everything in the panel uses `colors.onHero`: the headline in `titleLarge`, the warm line in `body`, the caption in `caption`. The bar uses `ProgressTone.onHero`. | Same as Goals: quieter white falls short over the gradient. |
| Art | On the right of the band: a white badge (`colors.onHero`, `heroCardShadow`) 112 px wide with an amber check (`scheme.primary`), surrounded by the existing still `_Confetti` at its existing positions, in a fixed 300 × 200 box. Hidden from screen readers. | The badge's amber-on-white check works on either end of the gradient. |
| Confetti colours | On the band: `onHero`, `onHeroQuiet`, `brand`, `chrome`. On the card (phone) they stay as they are. | The card's colours come from the gradient itself and would disappear on it. The pale gold in the mockup is `brand`. *(My call.)* |
| Copy | No new copy. Reuses `todayAllDone`, `todayAllDoneBody` / `todayAllDoneBodyUnnamed` and `todayDone`. | |
| The empty "Tasks" header | Not shown in the done state, on desktop and on the phone. | A header with no rows under it. The ticked task's slide-out happens in the outgoing branch, which `FadeSwap` keeps on screen while it fades. *(Phone added on Paul's request, 2026-11-19.)* |
| Catch up | On desktop in the done state, it moves from the side column into the main column, after today's events, open and without Show/Hide (as it is in the side column now). The side column keeps the volume card and the ritual invitation. | It is the next thing worth doing, and it is what the warm line promises ("they'll show up here"). |
| Nothing to catch up | The main column holds only today's events, or nothing. The columns stay as they are. | No placeholder (working rules). The band already carries the moment. |
| Transition | Ticking the last row cross-fades the band from the due layout (greeting and white card) to the done layout, through `FadeSwap` at `AppMotion.slow`. The greeting is in both, so it never dims. Undoing the tick goes back the same way. | The same motion the card has now. |
| Screen readers | The greeting and the all-done panel are separate nodes, in that order. The panel reads its headline, the warm line, then "N of N done". It never reads the bar as a percentage. | Matches the phone card. |
| Narrow desktop | From 1200 px (`Breakpoints.desktop`) the greeting column is `Expanded`, and the art box is fixed. French text at 1.3× wraps inside the panel and never overflows. | The band is about 850 px wide at 1200. |
| Phone and tablet | Otherwise unchanged: the white all-done card in the hero, and Catch up as it is now. | Out of scope. |

## Behaviour

On desktop, the band shows the done layout exactly when the page is in its
`done` branch: nothing due, no open task today, and at least one row ticked
today. In every other branch the band is unchanged: greeting, plus the white
card for `due`, or the greeting alone.

Done when:

- The desktop done state matches both PNGs: structure, order, colours and
  corners. Spacing may be off by a few px.
- The new previews `today_all_done_desktop_light` / `_dark` have goldens
  regenerated through CI.
- `dart format .`, `flutter analyze`, `flutter test` are clean.
