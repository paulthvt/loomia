---
inclusion: auto
name: specs-and-plans
description: How Loomia designs and plans a feature before coding. Use when starting a feature or epic, writing a design or spec, breaking work into tasks, or implementing an existing plan.
---

# Specs and plans

Designs and plans live in `docs/superpowers/`, written with the Superpowers
workflow in Claude Code. They are the only spec format in this repo: do not
create `.kiro/specs/`, write to the same folders instead.

- **Spec** (what and why): `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
  Intent, a *Decisions* table (question, decision, reason), then the behaviour.
  Name the epic/issue and link the Figma section.
- **Plan** (how): `docs/superpowers/plans/YYYY-MM-DD-<topic>.md`. Header with
  Goal, Architecture, Tech Stack, Spec link; then *Global Constraints*,
  *Rulings made while planning*, *Review Focus*, and `### Task N:` sections
  with `- [ ]` steps that name exact files, code and the test that pins each
  behaviour.

Before writing code for an issue, read its spec and, if one exists, its plan.
Earlier specs record decisions that still hold; check them before re-deciding.

When implementing a plan: work task by task, test first, tick each `- [ ]`
as it is done, and run the checks in `AGENTS.md` before calling a task done.
The header line "REQUIRED SUB-SKILL: superpowers:…" names Claude Code skills;
in Kiro, just execute the tasks in order.

A new UI pattern (not a reuse of existing components) is mocked in Figma
before it is planned: file `spz2vsSK8gbt1Ok2rW1sdQ`, page "04 — Screens
(Light)", one section per issue named "<Topic> — #<issue>".

Latest examples to copy the shape from:

#[[file:docs/superpowers/specs/2026-10-07-calendar-design.md]]
