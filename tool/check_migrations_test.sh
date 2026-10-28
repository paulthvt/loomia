#!/usr/bin/env bash
# Runs tool/check_migrations.sh on small SQL files: what it must flag, and
# what it must let through (#394). `bash tool/check_migrations_test.sh`.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
failed=0

expect() { # expect <exit code> <sql> <why>
  printf '%s\n' "$2" > "$dir/m.sql"
  local code=0
  bash "$here/check_migrations.sh" "$dir/m.sql" > /dev/null 2>&1 || code=$?
  if [ "$code" != "$1" ]; then
    echo "FAIL ($code, wanted $1): $3"
    failed=1
  fi
}

# Breaks the released app: flagged.
expect 1 'alter table public.task drop column note;' 'drop column'
expect 1 'ALTER TABLE public.task DROP COLUMN IF EXISTS note;' 'upper case'
expect 1 'drop table public.task;' 'drop table'
expect 1 'drop view public.today;' 'drop view'
expect 1 'drop function public.complete_task(uuid, date);' 'drop function'
expect 1 'drop type public.repeat_unit;' 'drop type'
expect 1 'alter table public.task rename column note to notes;' 'rename column'
expect 1 'alter table public.task rename to todo;' 'rename table'
expect 1 'alter type public.repeat_unit rename value '"'"'day'"'"' to '"'"'days'"'"';' 'rename enum value'
expect 1 'alter table public.task alter column note set not null;' 'set not null'
expect 1 'alter table public.task alter column note type varchar(80);' 'column type'
expect 1 'truncate public.task;' 'truncate'
expect 1 'delete from public.task where done_on is null;' 'delete'
expect 1 'alter table public.task
  drop column note;' 'over two lines'

# Additive, or a rebuild of something the app never reads: allowed.
expect 0 'alter table public.task add column alert boolean not null default true;' 'add column'
expect 0 'drop trigger task_set_updated_at on public.task;' 'drop trigger'
expect 0 'drop policy "owner" on public.task;' 'drop policy'
expect 0 'drop index task_owner_idx;' 'drop index'
expect 0 'create or replace function public.f() returns int language sql as $$ select 1 $$;' 'replace function'
expect 0 '-- we never drop column note here' 'a comment'
expect 0 'revoke all on public.task from anon, authenticated;' 'revoke then grant'
expect 0 'alter table public.task alter column note drop not null;' 'drop not null'
expect 0 'create or replace function public.delete_task(p_id uuid) returns void
language plpgsql as $$
begin
  delete from public.task where id = p_id;
end $$;' 'a function body that deletes when called'
expect 0 'alter table public.task rename constraint a to b;' 'rename constraint'

[ "$failed" = 0 ] && echo "check_migrations: all cases pass"
exit "$failed"
