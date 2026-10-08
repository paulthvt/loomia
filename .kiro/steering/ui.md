---
inclusion: fileMatch
fileMatchPattern: ["lib/**/presentation/**", "lib/core/ui/**", "lib/app/**"]
---

# UI

- Design system and components: `docs/design/design-system.md`,
  `docs/design/components.md`, `docs/design/responsive-design.md`. The rules
  that decide arguments:

#[[file:docs/design/design-principles.md]]

- Reuse `lib/core/ui/` before building a widget.
- `FilledButton.tonal` / `.tonalIcon` always take
  `style: AppTheme.tonal(context)`; without it the button renders Material's
  blue-grey instead of the brand tonal. The check ring is
  `IconButton(style: AppTheme.resolveRing(context))`.
- Async handlers read `ref` / `context` values (and capture the
  `ScaffoldMessenger`) before the first `await`.
- A new or changed `@Preview` needs its golden regenerated through CI; see the
  testing steering.
