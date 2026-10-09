import { withSupabase } from 'npm:@supabase/server@1.8.0'

// Deletes the caller's own account — and only theirs: the id comes from the
// verified session JWT, never from the request body.
//
// Whatever a user owns must reference auth.users with `on delete cascade`, so
// this stays a single call as tables arrive. Storage objects are the
// exception: they do not cascade, so the user's photo folder is emptied first.
export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    if (req.method !== 'POST') return new Response(null, { status: 405 })

    const id = ctx.userClaims!.id
    const avatars = ctx.supabaseAdmin.storage.from('avatars')
    for (;;) {
      const { data, error } = await avatars.list(id, { limit: 1000 })
      if (error) {
        console.error('delete-account: listing photos failed', error)
        return Response.json({ error: 'delete_failed' }, { status: 500 })
      }
      if (data.length === 0) break
      const { error: removeError } = await avatars.remove(
        data.map((file) => `${id}/${file.name}`),
      )
      if (removeError) {
        console.error('delete-account: removing photos failed', removeError)
        return Response.json({ error: 'delete_failed' }, { status: 500 })
      }
    }

    const { error } = await ctx.supabaseAdmin.auth.admin.deleteUser(id)
    if (error) {
      console.error('delete-account failed', error)
      return Response.json({ error: 'delete_failed' }, { status: 500 })
    }
    return new Response(null, { status: 204 })
  }),
}
