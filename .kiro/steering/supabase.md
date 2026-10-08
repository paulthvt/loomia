---
inclusion: fileMatch
fileMatchPattern: ["supabase/**", "lib/core/supabase/**", "lib/features/*/data/**"]
---

# Supabase

- Schema changes only through a new file from `supabase migration new <name>`.
  Never edit an applied migration, never change the schema or auth in the
  dashboard. Auth settings live in `supabase/config.toml`; secrets are
  `env(...)` references.
- A new table, in the same migration: RLS enabled, one owner policy per
  command on `owner_id = (select auth.uid())`, `revoke all ... from anon,
  authenticated`, then grant only what is needed to `authenticated`. Add its
  pgTAP test in `supabase/tests/`. `schema_rls_test.sql` fails CI otherwise.
- A rule every reader must agree on (current step, due date) is computed in
  Postgres once. The Dart fake in `test/features/workflows/server_rule.dart`
  is the only other copy; keep the two in step.
- Client access sits behind repositories in `features/<x>/data/`; widgets
  never call Supabase. The service-role key is never in this repo.
- Migrations reach the hosted project by hand after merge (`supabase db push`).

The conventions in full, with the reasons:

#[[file:docs/architecture.md]]
