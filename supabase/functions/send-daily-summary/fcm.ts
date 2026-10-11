// FCM HTTP v1 with a service account, by hand: an RS256 JWT signed with
// WebCrypto, exchanged for an OAuth token. No Google library for two requests.
import { type Outcome, outcome } from './message.ts'

export type ServiceAccount = {
  project_id: string
  client_email: string
  private_key: string
}

const tokenUrl = 'https://oauth2.googleapis.com/token'
const scope = 'https://www.googleapis.com/auth/firebase.messaging'

export function fcmSender(
  account: ServiceAccount,
  fetchFn: typeof fetch = fetch,
  now: () => number = Date.now,
): (message: unknown) => Promise<Outcome> {
  let cached: { token: string; until: number } | undefined

  async function accessToken(): Promise<string> {
    if (cached && cached.until > now()) return cached.token
    const iat = Math.floor(now() / 1000)
    const jwt = await signJwt(account.private_key, {
      iss: account.client_email,
      scope,
      aud: tokenUrl,
      iat,
      exp: iat + 3600,
    })
    const response = await fetchFn(tokenUrl, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    })
    if (!response.ok) throw new Error(`oauth ${response.status}`)
    const { access_token, expires_in } = await response.json()
    // Renewed 5 minutes early.
    cached = { token: access_token, until: now() + (expires_in - 300) * 1000 }
    return access_token
  }

  return async (message) => {
    const response = await fetchFn(
      `https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`,
      {
        method: 'POST',
        headers: {
          authorization: `Bearer ${await accessToken()}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify(message),
      },
    )
    const body = await response.json().catch(() => null)
    return outcome(response.status, body)
  }
}

async function signJwt(pem: string, claims: object): Promise<string> {
  const der = Uint8Array.from(
    atob(pem.replace(/-----[A-Z ]+-----/g, '').replace(/\s/g, '')),
    (c) => c.charCodeAt(0),
  )
  const key = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const encoder = new TextEncoder()
  const head = base64url(
    encoder.encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })),
  )
  const body = base64url(encoder.encode(JSON.stringify(claims)))
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    encoder.encode(`${head}.${body}`),
  )
  return `${head}.${body}.${base64url(new Uint8Array(signature))}`
}

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}
