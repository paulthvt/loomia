-- The month-end push (#148). Its own migration: a new enum value can't be
-- used in the transaction that adds it (20261013132208_month_ritual_push.sql
-- uses it).
alter type public.notification_kind add value 'month_ritual';
