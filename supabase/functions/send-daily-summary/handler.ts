import {
  type Message,
  type Outcome,
  type RitualClaim,
  ritualMessage,
  summaryMessage,
} from './message.ts'

/** notification_kind; a device only gets the kinds its app lists. */
export type Kind = 'daily_summary' | 'month_ritual'

export type Claim = { owner_id: string; local_date: string; people: number }
export type Device = {
  owner_id: string
  token: string
  locale: string
  push_kinds: Kind[]
}

/** One kind of push: who is due now (already claimed), and what they get. */
export type Job<C extends { owner_id: string }> = {
  kind: Kind
  claim(): Promise<C[]>
  /** Hands the claim back for the next run. */
  release(claim: C): Promise<void>
  message(claim: C, device: Device): Message
}

export type Deps = {
  devicesOf(owners: string[]): Promise<Device[]>
  drop(tokens: string[]): Promise<void>
  send(message: Message): Promise<Outcome>
}

export type Result = {
  claimed: number
  sent: number
  dropped: number
  released: number
  failed: number
}

/** The daily summary (#269): claim_daily_summaries, per local day. */
export const summaryJob = (
  claim: () => Promise<Claim[]>,
  release: (owner: string, date: string) => Promise<void>,
): Job<Claim> => ({
  kind: 'daily_summary',
  claim,
  release: (c) => release(c.owner_id, c.local_date),
  message: (c, d) => summaryMessage(d.token, d.locale, c.people),
})

/** The month-end push (#148): claim_month_rituals, per half (#354). */
export const ritualJob = (
  claim: () => Promise<RitualClaim[]>,
  release: (owner: string, date: string) => Promise<void>,
): Job<RitualClaim> => ({
  kind: 'month_ritual',
  claim,
  release: (c) => release(c.owner_id, c.claim_date),
  message: (c, d) => ritualMessage(d.token, d.locale, c),
})

/**
 * One run of one kind: claim, send to every phone of each claimed user whose
 * app shows that kind, drop dead tokens, and hand a claim back when nothing
 * went out but a retry might work. A claim with no phone is kept: there is
 * nothing to retry.
 */
export async function handle<C extends { owner_id: string }>(
  deps: Deps,
  job: Job<C>,
): Promise<Result> {
  const claims = await job.claim()
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
    devices = (await deps.devicesOf(claims.map((c) => c.owner_id)))
      .filter((d) => d.push_kinds.includes(job.kind))
  } catch (error) {
    // Nothing was sent: every claim goes back for the next run.
    for (const c of claims) await job.release(c)
    throw error
  }

  const dead: string[] = []
  for (const claim of claims) {
    const outcomes = await Promise.all(
      devices
        .filter((d) => d.owner_id === claim.owner_id)
        .map(async (d) => {
          const o = await deps
            .send(job.message(claim, d))
            .catch((): Outcome => 'retry')
          if (o === 'drop') dead.push(d.token)
          return o
        }),
    )
    result.sent += outcomes.filter((o) => o === 'sent').length
    result.failed += outcomes.filter((o) => o === 'failed').length
    if (!outcomes.includes('sent') && outcomes.includes('retry')) {
      await job.release(claim)
      result.released++
    }
  }
  if (dead.length > 0) {
    await deps.drop(dead)
    result.dropped = dead.length
  }
  return result
}
