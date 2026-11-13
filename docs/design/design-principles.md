# Design principles

Seven rules. They decide arguments. If a screen breaks one, the screen is wrong.

## 1. One question first

Every screen either answers **"What should I do today?"** or gets out of the way
of the screen that does. Today is the home; everything else is support.

*In practice:* the first viewport on Today shows actions, never analytics. New
features must say where they appear in a user's day before they get a screen.

## 2. People before records

A contact is a person, not a row of fields. Name, face, and the last real thing
that happened outrank completeness of data.

*In practice:* names in the largest type on any row. No field-count or
profile-completion meters. No table views on mobile. Avatars are people, not
decoration — initials over generic glyphs.

## 3. The app remembers, the user decides

Loomia holds the whole history so the user never has to. It shows a short list and
keeps the rest one tap away.

*In practice:* Today caps at ~5 suggested actions. History is chronological and
collapsed by default. Never present a backlog as a debt to clear.

## 4. Suggest, never nag

Reminders are offers. Urgency must be earned by a real date (birthday,
commitment, promise), never manufactured by styling.

*In practice:* red is reserved for destructive actions and genuine errors — never
for "overdue". Overdue reads as neutral-warm. No badge counts on navigation. No
push before a user opts into that specific kind of nudge.

## 5. Progress without pressure

Goals show direction and pace, never judgement. The user compares against their
own intent, never against other people.

*In practice:* "slightly behind pace, 11 days left" — not "you are failing". No
leaderboards, no ranks, no streaks that break, no trophies. Behind-pace uses the
warm secondary, not error red.

*First exception, ranks:* a rank, when the user's company has ranks (dōTERRA),
is a private target the user sets for themselves — "Aiming for Elite" — or a fact
they write on a team member's page. Never a badge, never shown outside Goals
and that page, never compared or ranked against anyone.

*Second exception, acknowledge, don't celebrate:* when a month closes,
reaching your own target may be marked once — the ring draws closed and holds.
The month review has the same screen, tone and layout for a miss; only the
facts differ. No sound, no loop, no shareable card. A celebration
for a hit would make the quiet screen for a miss read as a verdict. On Today,
the all-done hero shows a static confetti illustration (hidden from screen readers),
a warm line, and a full bar — a moment of recognition, not a looping celebration.

## 6. Structure from space and type, not from chrome

Hierarchy comes from whitespace, type weight, and one accent colour. Borders and
shadows are a last resort, not a default.

*In practice:* one elevation level for real overlays only (sheets, menus,
dialogs). Content surfaces are flat, separated by space or a 1px hairline. No
card inside a card. No gradient unless it carries meaning.

## 7. One identity, native manners

Same colours, type, and components on Android, iOS, and Web. Layout, density,
and input conventions adapt per platform and per size class.

*In practice:* one Flutter widget tree per screen, branching on
`context.screenSize`. Platform-specific behaviour (scroll physics, share sheets,
keyboard shortcuts, hover) is welcome; platform-specific visual identity is not.

## Language rules that follow from the above

Never in UI copy: recruit, downline, upline, rank, prospect*ing*, close, pitch,
leads, sales funnel, hustle.

Use instead: contact, person, team, follow-up, conversation, customer, prospect,
goal.

"Prospect" is allowed as a noun for a person at that stage — it is the word the
people using Loomia already use for themselves. The activity ("prospecting") stays
banned.
