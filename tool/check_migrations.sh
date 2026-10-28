#!/usr/bin/env bash
# Fails on SQL that would break the released app once pushed (#394): the
# hosted database gets every migration at merge, while phones keep the
# previous build. Additive changes pass; a drop, a rename, a tighter column or
# deleted data needs two releases (AGENTS.md → Working rules) and the
# `breaking-migration` label on its PR.
#
#   bash tool/check_migrations.sh supabase/migrations/<file>.sql ...
#
# ponytail: a text check. It reads statements, not their effect: a function
# whose parameters changed under `create or replace` (a new overload) or a
# policy rewritten narrower passes. The label and the PR template's Database
# section are the backstop.
set -euo pipefail

status=0
for file in "$@"; do
  # One line, lower case, without comments and dollar-quoted bodies (a
  # function that deletes when called deletes nothing now).
  found=$(perl -0777 -ne '
    s/--[^\n]*//g;
    s/\$([a-z_]*)\$.*?\$\1\$//gs;
    s/\s+/ /g;
    $_ = lc;
    my @hits;
    push @hits, $1 while /\b(drop (?:table|column|view|materialized view|function|procedure|type|schema)\b)/g;
    push @hits, "rename" if /\brename (?!constraint\b)/;
    push @hits, "set not null" if /\bset not null\b/;
    push @hits, "column type" if /\balter column [a-z_"]+ (?:set data )?type\b/;
    push @hits, "truncate" if /\btruncate\b/;
    push @hits, "delete from" if /\bdelete from\b/;
    print join(", ", @hits);
  ' "$file")
  if [ -n "$found" ]; then
    echo "$file: $found"
    status=1
  fi
done

if [ "$status" != 0 ]; then
  cat >&2 <<'EOF'

These statements break the released app once `supabase db push` runs at
merge: phones keep the previous build. Ship the new thing beside the old one
first, drop the old one in a later release (AGENTS.md → Working rules). When
this PR is that later step, add the `breaking-migration` label.
EOF
fi
exit "$status"
