// The pure part of `report-bug` (#463): what a report may contain, what the
// issue says, and the order of the two side effects. index.ts wires it to
// the NAS and GitHub.

export type LogEntry = {
  time: string
  level: string
  logger: string
  message: string
  error: string | null
  stack: string | null
}

export type Report = {
  id: string
  /** The tester's own title; null from an app older than #467. */
  title: string | null
  /** May be empty when there is a title. */
  comment: string
  png: Uint8Array<ArrayBuffer>
  facts: Record<string, unknown>
  logs: LogEntry[]
}

export type Deps = {
  isReporter(userId: string): Promise<boolean>
  /** Stores the PNG under [name], overwriting; returns its URL. */
  put(name: string, png: Uint8Array<ArrayBuffer>): Promise<string>
  /** Returns the new issue's number. */
  createIssue(title: string, body: string): Promise<number>
}

const maxTitle = 100
const maxComment = 5000
const maxPng = 5 * 1024 * 1024
const maxLogs = 200
const pngMagic = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

const isObject = (v: unknown): v is Record<string, unknown> =>
  typeof v === 'object' && v !== null && !Array.isArray(v)

const decode = (b64: string): Uint8Array<ArrayBuffer> | null => {
  // Base64 is 4/3 of the bytes: refuse before decoding a huge string.
  if (b64.length > Math.ceil(maxPng / 3) * 4) return null
  try {
    return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
  } catch {
    return null
  }
}

const str = (v: unknown) => (typeof v === 'string' ? v : null)

const parseLog = (v: unknown): LogEntry | null => {
  if (!isObject(v)) return null
  const [time, level, logger, message] = [v.time, v.level, v.logger, v.message]
    .map(str)
  if (time === null || level === null || logger === null || message === null) {
    return null
  }
  return { time, level, logger, message, error: str(v.error), stack: str(v.stack) }
}

/** Null unless [json] is a report the app could have sent. */
export function parse(json: unknown): Report | null {
  if (!isObject(json)) return null
  const { id, title, comment, screenshot, facts, logs } = json
  if (typeof id !== 'string' || !uuid.test(id)) return null
  // An older app sends no title: then the comment's first line is the title,
  // so the comment must be there.
  let heading: string | null = null
  if (title !== undefined) {
    if (typeof title !== 'string') return null
    heading = title.trim().replace(/\s+/g, ' ')
    if (heading.length === 0 || heading.length > maxTitle) return null
  }
  if (typeof comment !== 'string') return null
  const text = comment.trim()
  if (text.length > maxComment) return null
  if (heading === null && text.length === 0) return null
  if (typeof screenshot !== 'string') return null
  const png = decode(screenshot)
  if (png === null || png.length > maxPng) return null
  if (!pngMagic.every((b, i) => png[i] === b)) return null
  if (!isObject(facts)) return null
  if (!Array.isArray(logs) || logs.length > maxLogs) return null
  const entries = logs.map(parseLog)
  if (entries.some((e) => e === null)) return null
  return {
    id,
    title: heading,
    comment: text,
    png,
    facts: knownFacts(facts),
    logs: entries as LogEntry[],
  }
}

/** What `collectDeviceFacts` sends; anything else never reaches the issue. */
const factKeys = [
  'appVersion',
  'buildNumber',
  'platform',
  'osVersion',
  'locale',
  'route',
  'screen',
  'brightness',
]

// The issue is public, so this is the gate, not the app: only the known
// keys, each a short string (or null).
function knownFacts(facts: Record<string, unknown>) {
  const kept: Record<string, string | null> = {}
  for (const key of factKeys) {
    if (!(key in facts)) continue
    const v = facts[key]
    kept[key] = typeof v === 'string' || typeof v === 'number'
      ? String(v).slice(0, 100)
      : null
  }
  return kept
}

export function issueTitle(comment: string): string {
  const first = comment.split('\n').map((l) => l.trim()).find((l) => l) ?? ''
  const cut = first.length > 60 ? `${first.slice(0, 59)}…` : first
  return `Bug report: ${cut}`
}

// One line, no pipe: a fact can't open a new row or column.
const cell = (v: unknown) =>
  String(v ?? '—').replace(/\s+/g, ' ').replace(/\|/g, '\\|')

// Inside a fenced block, a line of backticks would close it early.
const fenced = (s: string) => s.replace(/`{3,}/g, (m) => m.replace(/`/g, 'ˋ'))

export function issueBody(r: Report, userId: string, screenshotUrl: string) {
  const facts = Object.entries(r.facts)
    .map(([k, v]) => `| ${cell(k)} | ${cell(v)} |`)
    .join('\n')
  const logs = r.logs
    .map((l) => {
      const line = `${l.time} ${l.level} ${l.logger}: ${l.message.replace(/\n/g, ' ')}`
      const error = l.error ? ` · ${l.error}` : ''
      const stack = l.stack ? `\n${l.stack}` : ''
      return fenced(line + error + stack)
    })
    .join('\n')
  // The screenshot is a link, not an image: GitHub's image proxy can't sign
  // in to the NAS, and the screenshot must stay private.
  return [
    r.comment || '_No description._',
    '',
    `[Screenshot](${screenshotUrl}) (NAS sign-in)`,
    '',
    '| | |',
    '| --- | --- |',
    facts,
    `| reporter | ${cell(userId)} |`,
    '',
    `<details><summary>Last ${r.logs.length} log lines</summary>`,
    '',
    '```',
    logs,
    '```',
    '',
    '</details>',
  ].join('\n')
}

const json = (status: number, body: unknown) => Response.json(body, { status })

/** [today] is the UTC date, `YYYY-MM-DD`, that prefixes the file name. */
export async function handle(
  userId: string,
  body: unknown,
  deps: Deps,
  today: string,
): Promise<Response> {
  const report = parse(body)
  if (!report) return json(400, { error: 'invalid' })
  if (!(await deps.isReporter(userId))) return json(403, { error: 'not_allowed' })
  // Named by the report's id, so a retry overwrites instead of piling up.
  let url: string
  try {
    url = await deps.put(`${today}-${report.id}.png`, report.png)
  } catch (e) {
    console.error('report-bug: upload failed', userId, String(e))
    return json(502, { error: 'upload_failed' })
  }
  try {
    const issue = await deps.createIssue(
      report.title ?? issueTitle(report.comment),
      issueBody(report, userId, url),
    )
    return json(200, { issue })
  } catch (e) {
    // ponytail: the PNG stays on the NAS without an issue until a retry
    // overwrites it; a tester who gives up leaves one orphan file.
    console.error('report-bug: issue failed', userId, String(e))
    return json(502, { error: 'issue_failed' })
  }
}
