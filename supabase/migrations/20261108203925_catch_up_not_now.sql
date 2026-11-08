-- Catch up: Not now (#481). The day the user last said Not now to catching
-- up with this person; Today leaves them out of Catch up for a month from
-- it. Nothing is logged: their last contact stays what it was.
-- Additive and nullable, so the released app reads person as before.

alter table public.person
  add column catch_up_dismissed_on date;
