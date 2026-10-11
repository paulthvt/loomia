import { type Outcome, summaryMessage } from './message.ts'

export type Claim = { owner_id: string; local_date: string; people: number }
export type Device = { owner_id: string; token: string; locale: string }

export type Deps = {
  /** claim_daily_summaries(): who is due now, already claimed. */
  claim(): Promise<Claim[]>
  devicesOf(owners: string[]): Promise<Device[]>
  drop(tokens: string[]): Promise<void>
  release(owner: string, date: string): Promise<void>
  send(message: ReturnType<typeof summaryMessage>): Promise<Outcome>
}

export type Result = {
  claimed: number
  sent: number
  dropped: number
  released: number
  failed: number
}

/**
 * One run: claim, send to every phone of each claimed user, drop dead tokens,
 * and hand a day back when nothing went out but a retry might work. A claim
 * with no phone is kept: there is nothing to retry.
 */
export async function handle(deps: Deps): Promise<Result> {
  const claims = await deps.claim()
  const result: Result = {
    claimed: claims.length,
    sent: 0,
    dropped: 0,
    released: 0,
    failed: 0,
  }
  if (claims.length === 0) return result

  let devices: Device[]
  try {
    devices = await deps.devicesOf(claims.map((c) => c.owner_id))
  } catch (error) {
    // Nothing was sent: every day goes back for the next run.
    for (const c of claims) await deps.release(c.owner_id, c.local_date)
    throw error
  }

  const dead: string[] = []
  for (const claim of claims) {
    const outcomes = await Promise.all(
      devices
        .filter((d) => d.owner_id === claim.owner_id)
        .map(async (d) => {
          const o = await deps
            .send(summaryMessage(d.token, d.locale, claim.people))
            .catch((): Outcome => 'retry')
          if (o === 'drop') dead.push(d.token)
          return o
        }),
    )
    result.sent += outcomes.filter((o) => o === 'sent').length
    result.failed += outcomes.filter((o) => o === 'failed').length
    if (!outcomes.includes('sent') && outcomes.includes('retry')) {
      await deps.release(claim.owner_id, claim.local_date)
      result.released++
    }
  }
  if (dead.length > 0) {
    await deps.drop(dead)
    result.dropped = dead.length
  }
  return result
}
