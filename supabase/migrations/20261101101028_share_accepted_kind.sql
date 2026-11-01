-- The invite-accepted push (#423). Its own migration: a new enum value can't
-- be used in the transaction that adds it.
alter type public.notification_kind add value 'share_accepted';
