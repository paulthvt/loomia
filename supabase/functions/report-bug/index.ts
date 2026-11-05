import { withSupabase } from 'npm:@supabase/server@1.8.0'
import { handle } from './handler.ts'

// In-app bug reports (#463). Only a user Paul flagged by hand
// (`app_metadata.bug_reporter`) may send one: the screenshot goes to his NAS
// over WebDAV, private, and the issue to paulthvt/loomia with a link to it.
// The flag is read from the user record, not the JWT, so removing it takes
// effect at once. Logs carry the user id and status codes, never content.
const token = Deno.env.get('GITHUB_ISSUES_TOKEN')
const nasUrl = Deno.env.get('NAS_WEBDAV_URL')?.replace(/\/+$/, '')
const nasUser = Deno.env.get('NAS_WEBDAV_USER')
const nasPassword = Deno.env.get('NAS_WEBDAV_PASSWORD')

export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') return new Response(null, { status: 405 })
    if (!token || !nasUrl || !nasUser || !nasPassword) {
      console.error('report-bug: a secret is not set')
      return Response.json({ error: 'not_configured' }, { status: 500 })
    }
    let body: unknown
    try {
      body = await req.json()
    } catch {
      return Response.json({ error: 'invalid' }, { status: 400 })
    }
    const userId = ctx.userClaims!.id
    return handle(userId, body, {
      isReporter: async (id) => {
        const { data, error } = await ctx.supabaseAdmin.auth.admin.getUserById(
          id,
        )
        if (error) throw error
        return data.user?.app_metadata?.bug_reporter === true
      },
      put: async (name, png) => {
        const url = `${nasUrl}/${name}`
        const res = await fetch(url, {
          method: 'PUT',
          headers: {
            Authorization: `Basic ${btoa(`${nasUser}:${nasPassword}`)}`,
            'Content-Type': 'image/png',
          },
          body: png,
        })
        await res.body?.cancel()
        if (!res.ok) throw new Error(`WebDAV ${res.status}`)
        return url
      },
      createIssue: async (title, issueBody) => {
        const res = await fetch(
          'https://api.github.com/repos/paulthvt/loomia/issues',
          {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${token}`,
              Accept: 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
            body: JSON.stringify({
              title,
              body: issueBody,
              labels: ['bug-report'],
            }),
          },
        )
        if (!res.ok) {
          await res.body?.cancel()
          throw new Error(`GitHub ${res.status}`)
        }
        return ((await res.json()) as { number: number }).number
      },
    }, new Date().toISOString().slice(0, 10))
  }),
}
