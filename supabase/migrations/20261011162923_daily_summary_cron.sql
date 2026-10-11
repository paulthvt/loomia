-- The daily summary's clock (#269): every 15 minutes pg_cron posts to the
-- send-daily-summary Edge Function, which claims and sends. No queue, no
-- per-user timer. The function's URL and its `cron` secret key are Vault
-- secrets set by hand on the hosted project (README → Push notifications);
-- without them (CI, a fresh local stack) a run only tidies up.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

-- security definer to read Vault and call pg_net; it takes no input and only
-- the cron job (postgres) may run it.
create function public.run_daily_summary() returns void
language plpgsql security definer set search_path = '' as $$
declare
  url text;
  key text;
begin
  delete from public.notification_sent
    where local_date < current_date - 30;

  select decrypted_secret into url from vault.decrypted_secrets
    where name = 'send_daily_summary_url';
  select decrypted_secret into key from vault.decrypted_secrets
    where name = 'send_daily_summary_key';
  if url is null or key is null then
    raise log 'send-daily-summary: no Vault secrets, nothing sent';
    return;
  end if;

  perform net.http_post(
    url := url,
    headers := jsonb_build_object(
      'apikey', key, 'content-type', 'application/json'),
    body := '{}'::jsonb,
    -- An Edge Function's wall-clock limit.
    timeout_milliseconds := 150000
  );
end $$;

revoke execute on function public.run_daily_summary()
  from public, anon, authenticated;

select cron.schedule(
  'send-daily-summary', '*/15 * * * *', 'select public.run_daily_summary()'
);
