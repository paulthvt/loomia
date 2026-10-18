import { withSupabase } from 'npm:@supabase/server@1.8.0'
import { fcmSender, type ServiceAccount } from './fcm.ts'
import {
  type Claim,
  type Device,
  handle,
  ritualJob,
  summaryJob,
} from './handler.ts'
import type { RitualClaim } from './message.ts'

// The daily summary (#269) and the month-end push (#148), called by pg_cron
// every 15 minutes with the `cron` named secret key
// (supabase/migrations/*_daily_summary_cron.sql). Postgres decides who is due
// and claims them; this sends. Logs carry counts only, never a token or a
// name.
const account = Deno.env.get('FCM_SERVICE_ACCOUNT')
const send = account
  ? fcmSender(JSON.parse(account) as ServiceAccount)
  : undefined

export default {
  fetch: withSupabase({ auth: 'secret:cron' }, async (req, ctx) => {
    if (req.method !== 'POST') return new Response(null, { status: 405 })
    if (!send) {
      console.error('send-daily-summary: FCM_SERVICE_ACCOUNT is not set')
      return Response.json({ error: 'not_configured' }, { status: 500 })
    }
    const db = ctx.supabaseAdmin
    const check = <T>({ data, error }: { data: T; error: unknown }): T => {
      if (error) throw error
      return data
    }
    try {
      const deps = {
        devicesOf: async (owners: string[]) =>
          check(
            await db
              .from('device_token')
              .select('owner_id, token, locale, push_kinds')
              .in('owner_id', owners),
          ) as Device[],
        drop: async (tokens: string[]) => {
          check(await db.rpc('drop_device_tokens', { p_tokens: tokens }))
        },
        send,
      }
      // One kind after the other; a failure in one doesn't skip the next.
      const run = (name: string, job: Parameters<typeof handle>[1]) =>
        handle(deps, job).catch((error) => {
          console.error(`send-daily-summary: ${name} failed`, error)
          return null
        })
      const summary = await run(
        'summary',
        summaryJob(
          async () => check(await db.rpc('claim_daily_summaries')) as Claim[],
          async (owner, date) => {
            check(
              await db.rpc('release_daily_summary', {
                p_owner: owner,
                p_date: date,
              }),
            )
          },
        ),
      )
      const ritual = await run(
        'ritual',
        ritualJob(
          async () =>
            check(await db.rpc('claim_month_rituals')) as RitualClaim[],
          async (owner, date) => {
            check(
              await db.rpc('release_month_ritual', {
                p_owner: owner,
                // The claim's date; the parameter kept its #148 name.
                p_plan: date,
              }),
            )
          },
        ),
      )
      const result = { summary, ritual }
      console.log('send-daily-summary', result)
      return Response.json(result, {
        status: summary && ritual ? 200 : 500,
      })
    } catch (error) {
      console.error('send-daily-summary failed', error)
      return Response.json({ error: 'send_failed' }, { status: 500 })
    }
  }),
}
