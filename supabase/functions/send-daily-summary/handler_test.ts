// deno test supabase/functions
import { deepStrictEqual as eq, ok } from 'node:assert/strict'
import { fcmSender } from './fcm.ts'
import { type Claim, type Deps, type Device, handle } from './handler.ts'
import { type Outcome, outcome, summaryMessage } from './message.ts'

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
    claim: () => Promise.resolve(claims),
    devicesOf: () => Promise.resolve(devices),
    drop: (tokens) => {
      calls.drop.push(tokens)
      return Promise.resolve()
    },
    release: (owner, date) => {
      calls.release.push(`${owner} ${date}`)
      return Promise.resolve()
    },
    send: (m) => {
      const a = answers[m.message.token]
      return a === 'throw'
        ? Promise.reject(new Error('net'))
        : Promise.resolve(a)
    },
  }
  return { deps, calls }
}

Deno.test('a run drops dead tokens and hands back what can be retried', async () => {
  const { deps, calls } = fakes(
    [
      { owner_id: 'A', local_date: '2026-10-12', people: 3 },
      { owner_id: 'B', local_date: '2026-10-12', people: 1 },
      { owner_id: 'C', local_date: '2026-10-12', people: 2 },
      { owner_id: 'D', local_date: '2026-10-12', people: 2 },
    ],
    [
      { owner_id: 'A', token: 'a1', locale: 'en' },
      { owner_id: 'A', token: 'a2', locale: 'fr' },
      { owner_id: 'B', token: 'b1', locale: 'en' },
      { owner_id: 'D', token: 'd1', locale: 'en' },
      { owner_id: 'D', token: 'd2', locale: 'en' },
    ],
    { a1: 'sent', a2: 'drop', b1: 'retry', d1: 'throw', d2: 'drop' },
  )
  const result = await handle(deps)
  eq(calls.drop, [['a2', 'd2']])
  eq(
    calls.release,
    ['B 2026-10-12', 'D 2026-10-12'],
    'not A (sent), not C (no phone)',
  )
  eq(result, { claimed: 4, sent: 1, dropped: 2, released: 2, failed: 0 })
})

Deno.test('nothing claimed, nothing asked', async () => {
  const { deps } = fakes([], [], {})
  deps.devicesOf = () => Promise.reject(new Error('not called'))
  eq((await handle(deps)).claimed, 0)
})

Deno.test('devices unreadable: every day goes back', async () => {
  const { deps, calls } = fakes(
    [{ owner_id: 'A', local_date: '2026-10-12', people: 1 }],
    [],
    {},
  )
  deps.devicesOf = () => Promise.reject(new Error('db'))
  await handle(deps).then(() => ok(false), () => {})
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
