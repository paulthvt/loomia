-- LRP on the contact (#255), part 1. The kinds are added alone: a new enum
-- value cannot be used in the transaction that adds it, and the next
-- migration names them in policies and checks.
alter type public.activity_kind add value 'loyalty_start';
alter type public.activity_kind add value 'loyalty_stop';
