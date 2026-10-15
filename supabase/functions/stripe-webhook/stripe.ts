// Pure helpers for the stripe-webhook function: signature verification and
// the mapping from a Stripe subscription to DuoTask's premium columns.
// No Deno or network APIs here, so stripe_test.ts can exercise all of it.

/** How far a signed timestamp may drift from now, as Stripe's SDKs default. */
export const DEFAULT_TOLERANCE_SECONDS = 300

/**
 * Extra time added to the paid-through date, so a renewal webhook that
 * arrives late (or is retried) doesn't briefly lock a paying pair out.
 * Cancellation is unaffected: `customer.subscription.deleted` sets
 * is_premium = false outright.
 */
export const RENEWAL_GRACE_SECONDS = 2 * 24 * 60 * 60

/** Subscription statuses that keep premium on. `past_due` is Stripe's
 * retry window; it ends in `canceled` or `unpaid`, which turn it off. */
const PREMIUM_STATUSES = new Set(['active', 'trialing', 'past_due'])

export class SignatureError extends Error {}

function hex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i)
  return diff === 0
}

export async function computeSignature(
  payload: string,
  timestamp: number,
  secret: string,
): Promise<string> {
  const enc = new TextEncoder()
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const mac = await crypto.subtle.sign('HMAC', key, enc.encode(`${timestamp}.${payload}`))
  return hex(mac)
}

/**
 * Verifies a `Stripe-Signature` header against the raw request body, as
 * documented at https://docs.stripe.com/webhooks#verify-manually.
 * Throws SignatureError on any failure; returns the signed timestamp.
 */
export async function verifyStripeSignature(
  payload: string,
  header: string | null,
  secret: string,
  options: { toleranceSeconds?: number; nowSeconds?: number } = {},
): Promise<number> {
  if (!secret) throw new SignatureError('webhook secret is not configured')
  if (!header) throw new SignatureError('missing Stripe-Signature header')

  let timestamp = NaN
  const signatures: string[] = []
  for (const part of header.split(',')) {
    const [k, v] = part.split('=', 2).map((s) => s?.trim())
    if (k === 't') timestamp = Number(v)
    else if (k === 'v1' && v) signatures.push(v)
  }
  if (!Number.isFinite(timestamp)) throw new SignatureError('no timestamp in header')
  if (signatures.length === 0) throw new SignatureError('no v1 signature in header')

  const tolerance = options.toleranceSeconds ?? DEFAULT_TOLERANCE_SECONDS
  const now = options.nowSeconds ?? Math.floor(Date.now() / 1000)
  if (Math.abs(now - timestamp) > tolerance) {
    throw new SignatureError('timestamp outside tolerance')
  }

  const expected = await computeSignature(payload, timestamp, secret)
  if (!signatures.some((s) => timingSafeEqual(s, expected))) {
    throw new SignatureError('signature mismatch')
  }
  return timestamp
}

export interface StripeSubscription {
  id: string
  customer: string | { id: string }
  status: string
  current_period_end?: number | null
  ended_at?: number | null
  items?: { data?: Array<{ current_period_end?: number | null }> }
}

export interface PremiumState {
  isPremium: boolean
  /** ISO timestamp, or null when not premium. */
  premiumUntil: string | null
}

export function customerId(sub: { customer: string | { id: string } }): string {
  return typeof sub.customer === 'string' ? sub.customer : sub.customer.id
}

/** Paid-through time in seconds. Newer Stripe API versions (2025-03-31+)
 * moved `current_period_end` from the subscription onto its items. */
export function periodEnd(sub: StripeSubscription): number | null {
  if (sub.current_period_end) return sub.current_period_end
  const ends = (sub.items?.data ?? [])
    .map((i) => i.current_period_end ?? 0)
    .filter((n) => n > 0)
  return ends.length ? Math.max(...ends) : null
}

export function premiumStateFor(sub: StripeSubscription): PremiumState {
  if (!PREMIUM_STATUSES.has(sub.status)) {
    return { isPremium: false, premiumUntil: null }
  }
  const end = periodEnd(sub)
  return {
    isPremium: true,
    // Unknown period end: leave open-ended; the next update or the
    // deletion event will settle it.
    premiumUntil: end ? new Date((end + RENEWAL_GRACE_SECONDS) * 1000).toISOString() : null,
  }
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function isUuid(value: unknown): value is string {
  return typeof value === 'string' && UUID_RE.test(value)
}
