// deno test supabase/functions
import { deepStrictEqual as eq, ok } from 'node:assert/strict'
import { type Deps, handle, issueBody, issueTitle, parse } from './handler.ts'

const id = '3f2b8c1e-9a4d-4e6b-8c2f-1a2b3c4d5e6f'
const user = '11111111-2222-4333-8444-555555555555'
const png = btoa(String.fromCharCode(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2))
const log = {
  time: '2026-11-05T10:00:00.000Z',
  level: 'INFO',
  logger: 'router',
  message: '→ /today',
  error: null,
  stack: null,
}
const body = (over: Record<string, unknown> = {}) => ({
  id,
  comment: 'The Plan button is gone\nafter I swiped back',
  screenshot: png,
  facts: { appVersion: '0.4.0', platform: 'iOS', route: '/today' },
  logs: [log],
  ...over,
})

type Calls = { put: string[]; issues: string[] }
const deps = (
  over: Partial<Deps> = {},
): { deps: Deps; calls: Calls } => {
  const calls: Calls = { put: [], issues: [] }
  return {
    calls,
    deps: {
      isReporter: () => Promise.resolve(true),
      put: (name) => {
        calls.put.push(name)
        return Promise.resolve(`https://nas.example/bugs/${name}`)
      },
      createIssue: (title) => {
        calls.issues.push(title)
        return Promise.resolve(123)
      },
      ...over,
    },
  }
}

Deno.test('rejects a user without the flag before any upload', async () => {
  const { deps: d, calls } = deps({ isReporter: () => Promise.resolve(false) })
  const res = await handle(user, body(), d, '2026-11-05')
  eq(res.status, 403)
  eq(await res.json(), { error: 'not_allowed' })
  eq(calls, { put: [], issues: [] })
})

Deno.test('parse accepts a well-formed report', () => {
  const r = parse(body())!
  eq(r.id, id)
  eq(r.png.length, 10)
  eq(r.logs.length, 1)
})

Deno.test('parse refuses what the app never sends', () => {
  const big = new Uint8Array(5 * 1024 * 1024 + 1)
  big.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
  let binary = ''
  for (let i = 0; i < big.length; i += 0x8000) {
    binary += String.fromCharCode(...big.subarray(i, i + 0x8000))
  }
  const bad: unknown[] = [
    null,
    'x',
    body({ comment: '' }),
    body({ comment: '   ' }),
    body({ comment: 'a'.repeat(5001) }),
    body({ comment: 7 }),
    body({ screenshot: btoa('GIF89a not a png') }),
    body({ screenshot: '%%%not base64' }),
    body({ screenshot: btoa(binary) }),
    body({ logs: Array(201).fill(log) }),
    body({ logs: 'x' }),
    body({ id: 'not-a-uuid' }),
    body({ id: '../../etc' }),
    body({ facts: 'x' }),
  ]
  for (const b of bad) eq(parse(b), null, JSON.stringify(b)?.slice(0, 80))
  ok(parse(body({ comment: 'a'.repeat(5000) })))
  ok(parse(body({ logs: Array(200).fill(log) })))
})

Deno.test('parse keeps only the known facts, as short strings', () => {
  const r = parse(body({
    facts: {
      appVersion: '0.4.0',
      osVersion: null,
      buildNumber: 40,
      route: 'x'.repeat(300),
      email: 'ana@example.com',
      name: 'Ana',
      platform: { nested: 'Ana' },
    },
  }))!
  eq(r.facts, {
    appVersion: '0.4.0',
    osVersion: null,
    buildNumber: '40',
    route: 'x'.repeat(100),
    platform: null,
  })
  ok(!issueBody(r, user, 'u').includes('ana@'))
  ok(!issueBody(r, user, 'u').includes('Ana'))
})

Deno.test('the tester\'s title becomes the issue title, as typed', async () => {
  const { deps: d, calls } = deps()
  await handle(user, body({ title: '  Plan button gone  ' }), d, '2026-11-05')
  eq(calls.issues, ['Plan button gone'])
})

Deno.test('with a title, the description may be empty', async () => {
  const r = parse(body({ title: 'Plan button gone', comment: '  ' }))!
  eq(r.comment, '')
  ok(issueBody(r, user, 'u').startsWith('_No description._'))
})

Deno.test('parse refuses a blank, long or non-string title', () => {
  for (const title of ['', '   ', 'x'.repeat(101), 7]) {
    eq(parse(body({ title })), null, String(title))
  }
  ok(parse(body({ title: 'x'.repeat(100) })))
})

Deno.test('without a title (an older app), the comment is still required', () => {
  eq(parse(body({ comment: '' })), null)
})

Deno.test('the title is the first line, cut at 60 characters', () => {
  eq(issueTitle('Button is gone\nmore'), 'Bug report: Button is gone')
  eq(issueTitle('  \nSecond line first'), 'Bug report: Second line first')
  const t = issueTitle('x'.repeat(100))
  eq(t, `Bug report: ${'x'.repeat(59)}…`)
})

Deno.test('the body has the comment, facts, a link, logs folded, no email', () => {
  const r = parse(body({
    logs: [{ ...log, error: 'PostgrestException 23505', stack: '#0 open' }],
  }))!
  const b = issueBody(r, user, 'https://nas.example/bugs/a.png')
  ok(b.includes('The Plan button is gone\nafter I swiped back'))
  ok(b.includes('| appVersion | 0.4.0 |'))
  ok(b.includes('[Screenshot](https://nas.example/bugs/a.png)'))
  ok(!b.includes('!['), 'no inline image: GitHub cannot sign in to the NAS')
  ok(b.includes('<details>'))
  ok(b.includes('INFO router: → /today · PostgrestException 23505'))
  ok(b.includes('#0 open'))
  ok(b.includes(user))
  ok(!b.includes('@'))
})

Deno.test('a fact or log cannot break out of its table or code block', () => {
  const r = parse(body({
    facts: { route: 'a | b\nc' },
    logs: [{ ...log, message: 'x\n```\n# heading' }],
  }))!
  const b = issueBody(r, user, 'u')
  ok(b.includes('| route | a \\| b c |'))
  ok(!b.includes('\n```\n# heading'))
})

Deno.test('a retry overwrites the same file', async () => {
  const { deps: d, calls } = deps()
  await handle(user, body(), d, '2026-11-05')
  await handle(user, body(), d, '2026-11-05')
  eq(calls.put, [`2026-11-05-${id}.png`, `2026-11-05-${id}.png`])
})

Deno.test('success returns the issue number', async () => {
  const { deps: d, calls } = deps()
  const res = await handle(user, body(), d, '2026-11-05')
  eq(res.status, 200)
  eq(await res.json(), { issue: 123 })
  eq(calls.issues, ['Bug report: The Plan button is gone'])
})

Deno.test('a bad body is a 400 before the allowlist is read', async () => {
  let asked = false
  const { deps: d } = deps({
    isReporter: () => {
      asked = true
      return Promise.resolve(true)
    },
  })
  const res = await handle(user, body({ comment: '' }), d, '2026-11-05')
  eq(res.status, 400)
  eq(asked, false)
})

Deno.test('an upload failure stops before GitHub', async () => {
  const { deps: d, calls } = deps({ put: () => Promise.reject(new Error('503')) })
  const res = await handle(user, body(), d, '2026-11-05')
  eq(res.status, 502)
  eq(await res.json(), { error: 'upload_failed' })
  eq(calls.issues, [])
})

Deno.test('an issue failure is a 502 issue_failed', async () => {
  const { deps: d } = deps({
    createIssue: () => Promise.reject(new Error('401')),
  })
  const res = await handle(user, body(), d, '2026-11-05')
  eq(res.status, 502)
  eq(await res.json(), { error: 'issue_failed' })
})
