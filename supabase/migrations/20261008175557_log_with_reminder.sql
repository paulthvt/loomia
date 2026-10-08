-- Log something with Remind me (#219): the entry and the reminder in one
-- transaction, so a failure leaves neither and a retry cannot log the entry
-- twice. Text is trimmed as the client trims it; RLS and the table checks
-- refuse a bad kind, a blank reminder or another owner's person.
create function public.log_with_reminder(
  p_person uuid,
  p_kind public.activity_kind,
  p_text text,
  p_on date,
  p_amount numeric,
  p_remind text,
  p_remind_on date
) returns void
language sql security invoker set search_path = '' as $$
  insert into public.activity (person_id, kind, text, happened_on, amount)
    values (p_person, p_kind, nullif(trim(p_text), ''), p_on, p_amount);
  insert into public.reminder (person_id, text, due_on)
    values (p_person, trim(p_remind), p_remind_on);
$$;

revoke execute on function public.log_with_reminder(
  uuid, public.activity_kind, text, date, numeric, text, date
) from public, anon;
grant execute on function public.log_with_reminder(
  uuid, public.activity_kind, text, date, numeric, text, date
) to authenticated;
