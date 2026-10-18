// deno test supabase/functions
import { deepStrictEqual as eq, ok } from 'node:assert/strict'
import { fcmSender } from './fcm.ts'
import {
  type Claim,
  type Deps,
  type Device,
  handle,
  type Kind,
  type Job,
  ritualJob,
  summaryJob,
} from './handler.ts'
import {
  monthName,
  type Outcome,
  outcome,
  ritualMessage,
  summaryMessage,
} from './message.ts'

Deno.test('the message is a loc key per language and count, no text', () => {
  const one = summaryMessage('t', 'fr', 1).message
  eq(one.android.notification, {
    body_loc_key: 'push_summary_body_one_fr',
    body_loc_args: ['1'],
  })
  eq(one.apns.payload.aps.alert, {
    'loc-key': 'push_summary_body_one_fr',
    'loc-args': ['1'],
  })
  eq(one.data, { type: 'daily_summary' })
  eq(
    summaryMessage('t', 'en', 3).message.android.notification.body_loc_key,
    'push_summary_body_other_en',
  )
  ok(!JSON.stringify(one).match(/"(title|body)"/))
})

Deno.test('the month-end push is the card, title and body, in the phone language', () => {
  const claim = {
    owner_id: 'A',
    to_close: '2026-09-01',
    to_plan: '2026-10-01',
    closes: true,
    claim_date: '2026-10-01',
  }
  const en = ritualMessage('t', 'en', claim).message
  eq(en.android.notification, {
    title_loc_key: 'push_ritual_title_en',
    title_loc_args: ['September', 'October'],
    body_loc_key: 'push_ritual_body_en',
    body_loc_args: ['October'],
  })
  eq(en.apns.payload.aps.alert, {
    'title-loc-key': 'push_ritual_title_en',
    'title-loc-args': ['September', 'October'],
    'loc-key': 'push_ritual_body_en',
    'loc-args': ['October'],
  })
  eq(en.data, { type: 'month_ritual' })
  ok(!JSON.stringify(en).match(/"(title|body)"/))

  eq(
    ritualMessage('t', 'fr', claim).message.android.notification.title_loc_args,
    ['septembre', 'octobre'],
  )
  eq(
    ritualMessage('t', 'fr', { ...claim, closes: false }).message.android
      .notification,
    {
      title_loc_key: 'push_ritual_plan_title_fr',
      title_loc_args: ['octobre'],
      body_loc_key: 'push_ritual_plan_body_fr',
      body_loc_args: [],
    },
  )
  eq(monthName('2027-01-01', 'en'), 'January', 'the 1st stays in its month')
})

Deno.test('FCM answers', () => {
  const error = (details: object[]) => ({ error: { details } })
  eq(outcome(200, {}), 'sent')
  eq(outcome(404, error([{ errorCode: 'UNREGISTERED' }])), 'drop')
  eq(outcome(403, error([{ errorCode: 'SENDER_ID_MISMATCH' }])), 'drop')
  eq(
    outcome(
      400,
      error([{ errorCode: 'INVALID_ARGUMENT' }, {
        fieldViolations: [{ field: 'message.token' }],
      }]),
    ),
    'drop',
  )
  eq(
    outcome(400, error([{ errorCode: 'INVALID_ARGUMENT' }])),
    'failed',
    'a bad payload is our bug, not a dead token',
  )
  eq(outcome(429, null), 'retry')
  eq(outcome(503, null), 'retry')
  eq(outcome(401, null), 'failed')
})

function fakes(
  claims: Claim[],
  devices: Device[],
  answers: Record<string, Outcome | 'throw'>,
) {
  const calls = { drop: [] as string[][], release: [] as string[] }
  const deps: Deps = {
    devicesOf: () => Promise.resolve(devices),
    drop: (tokens) => {
      calls.drop.push(tokens)
      return Promise.resolve()
    },
    send: (m) => {
      const a = answers[m.message.token]
      return a === 'throw'
        ? Promise.reject(new Error('net'))
        : Promise.resolve(a)
    },
  }
  const job: Job<Claim> = summaryJob(
    () => Promise.resolve(claims),
    (owner, date) => {
      calls.release.push(`${owner} ${date}`)
      return Promise.resolve()
    },
  )
  return { deps, job, calls }
}

const both: Kind[] = ['daily_summary', 'month_ritual']
const phone = (owner_id: string, token: string, locale = 'en'): Device => ({
  owner_id,
  token,
  locale,
  push_kinds: both,
})

Deno.test('a run drops dead tokens and hands back what can be retried', async () => {
  const { deps, job, calls } = fakes(
    [
      { owner_id: 'A', local_date: '2026-10-12', people: 3 },
      { owner_id: 'B', local_date: '2026-10-12', people: 1 },
      { owner_id: 'C', local_date: '2026-10-12', people: 2 },
      { owner_id: 'D', local_date: '2026-10-12', people: 2 },
    ],
    [
      phone('A', 'a1'),
      phone('A', 'a2', 'fr'),
      phone('B', 'b1'),
      phone('D', 'd1'),
      phone('D', 'd2'),
    ],
    { a1: 'sent', a2: 'drop', b1: 'retry', d1: 'throw', d2: 'drop' },
  )
  const result = await handle(deps, job)
  eq(calls.drop, [['a2', 'd2']])
  eq(
    calls.release,
    ['B 2026-10-12', 'D 2026-10-12'],
    'not A (sent), not C (no phone)',
  )
  eq(result, { claimed: 4, sent: 1, dropped: 2, released: 2, failed: 0 })
})

Deno.test('an app without the kind is not sent it, and the claim is kept', async () => {
  const { deps } = fakes(
    [],
    [{ ...phone('A', 'old'), push_kinds: ['daily_summary'] }, phone('B', 'new')],
    { old: 'retry', new: 'sent' },
  )
  const sent: string[] = []
  const send = deps.send
  deps.send = (m) => {
    sent.push(m.message.token)
    return send(m)
  }
  const released: string[] = []
  const claim = (owner_id: string) => ({
    owner_id,
    to_close: '2026-09-01',
    to_plan: '2026-10-01',
    closes: true,
    claim_date: '2026-10-01',
  })
  const result = await handle(
    deps,
    ritualJob(
      () => Promise.resolve([claim('A'), claim('B')]),
      (owner, plan) => {
        released.push(`${owner} ${plan}`)
        return Promise.resolve()
      },
    ),
  )
  eq(sent, ['new'])
  eq(released, [], 'A has no phone for it: nothing to retry')
  eq(result.sent, 1)
})

Deno.test('a month-end claim goes back under its own half', async () => {
  const released: string[] = []
  const job = ritualJob(
    () => Promise.resolve([]),
    (owner, date) => {
      released.push(`${owner} ${date}`)
      return Promise.resolve()
    },
  )
  await job.release({
    owner_id: 'A',
    to_close: '2026-09-01',
    to_plan: '2026-10-01',
    closes: false,
    claim_date: '2026-09-30',
  })
  eq(released, ['A 2026-09-30'], 'the drafting half, not the 1st')
})

Deno.test('nothing claimed, nothing asked', async () => {
  const { deps, job } = fakes([], [], {})
  deps.devicesOf = () => Promise.reject(new Error('not called'))
  eq((await handle(deps, job)).claimed, 0)
})

Deno.test('devices unreadable: every day goes back', async () => {
  const { deps, job, calls } = fakes(
    [{ owner_id: 'A', local_date: '2026-10-12', people: 1 }],
    [],
    {},
  )
  deps.devicesOf = () => Promise.reject(new Error('db'))
  await handle(deps, job).then(() => ok(false), () => {})
  eq(calls.release, ['A 2026-10-12'])
})

Deno.test('the sender signs a JWT, reuses its token, and posts the message', async () => {
  const keys = await crypto.subtle.generateKey(
    {
      name: 'RSASSA-PKCS1-v1_5',
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: 'SHA-256',
    },
    true,
    ['sign', 'verify'],
  )
  const der = new Uint8Array(
    await crypto.subtle.exportKey('pkcs8', keys.privateKey),
  )
  const pem = `-----BEGIN PRIVATE KEY-----\n${
    btoa(String.fromCharCode(...der))
  }\n-----END PRIVATE KEY-----\n`
  const requests: { url: string; init: RequestInit }[] = []
  const fetchFn = ((url: string, init: RequestInit) => {
    requests.push({ url, init })
    return Promise.resolve(
      url.includes('oauth2')
        ? Response.json({ access_token: 'at', expires_in: 3600 })
        : Response.json({ name: 'ok' }),
    )
  }) as typeof fetch
  const send = fcmSender(
    { project_id: 'p', client_email: 'sa@p.iam', private_key: pem },
    fetchFn,
  )

  eq(await send({ message: { token: 't' } }), 'sent')
  eq(await send({ message: { token: 't' } }), 'sent')
  eq(requests.filter((r) => r.url.includes('oauth2')).length, 1, 'token cached')

  const jwt = new URLSearchParams(String(requests[0].init.body)).get(
    'assertion',
  )!
  const [head, body, signature] = jwt.split('.')
  const bytes = (s: string) =>
    Uint8Array.from(
      atob(s.replace(/-/g, '+').replace(/_/g, '/')),
      (c) => c.charCodeAt(0),
    )
  ok(
    await crypto.subtle.verify(
      'RSASSA-PKCS1-v1_5',
      keys.publicKey,
      bytes(signature),
      new TextEncoder().encode(`${head}.${body}`),
    ),
    'signed with the service account key',
  )
  const claims = JSON.parse(new TextDecoder().decode(bytes(body)))
  eq([claims.iss, claims.aud], [
    'sa@p.iam',
    'https://oauth2.googleapis.com/token',
  ])
  eq(requests[1].url, 'https://fcm.googleapis.com/v1/projects/p/messages:send')
  eq(
    (requests[1].init.headers as Record<string, string>).authorization,
    'Bearer at',
  )
})
