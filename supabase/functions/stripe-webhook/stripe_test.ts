// Run with: deno test supabase/functions/stripe-webhook/stripe_test.ts
import { assert, assertEquals, assertRejects } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import {
  computeSignature,
  isUuid,
  periodEnd,
  premiumStateFor,
  RENEWAL_GRACE_SECONDS,
  SignatureError,
  verifyStripeSignature,
} from './stripe.ts'

const SECRET = 'whsec_test_secret'
const PAYLOAD = '{"id":"evt_1","type":"checkout.session.completed"}'
const NOW = 1_760_000_000

async function header(payload = PAYLOAD, t = NOW, secret = SECRET): Promise<string> {
  return `t=${t},v1=${await computeSignature(payload, t, secret)}`
}

Deno.test('accepts a correctly signed payload', async () => {
  const t = await verifyStripeSignature(PAYLOAD, await header(), SECRET, { nowSeconds: NOW })
  assertEquals(t, NOW)
})

Deno.test('accepts when any of several v1 signatures matches (secret rollover)', async () => {
  const good = await computeSignature(PAYLOAD, NOW, SECRET)
  const h = `t=${NOW},v1=${'0'.repeat(64)},v1=${good},v0=ignored`
  await verifyStripeSignature(PAYLOAD, h, SECRET, { nowSeconds: NOW })
})

Deno.test('rejects a tampered payload', async () => {
  const h = await header()
  await assertRejects(
    () => verifyStripeSignature(PAYLOAD.replace('evt_1', 'evt_2'), h, SECRET, { nowSeconds: NOW }),
    SignatureError,
  )
})

Deno.test('rejects the wrong secret', async () => {
  await assertRejects(
    async () =>
      verifyStripeSignature(PAYLOAD, await header(PAYLOAD, NOW, 'whsec_other'), SECRET, {
        nowSeconds: NOW,
      }),
    SignatureError,
  )
})

Deno.test('rejects a stale timestamp (replay)', async () => {
  await assertRejects(
    async () => verifyStripeSignature(PAYLOAD, await header(), SECRET, { nowSeconds: NOW + 301 }),
    SignatureError,
  )
})

Deno.test('rejects missing header, missing secret and malformed header', async () => {
  await assertRejects(() => verifyStripeSignature(PAYLOAD, null, SECRET), SignatureError)
  await assertRejects(async () => verifyStripeSignature(PAYLOAD, await header(), ''), SignatureError)
  await assertRejects(() => verifyStripeSignature(PAYLOAD, 'garbage', SECRET), SignatureError)
  await assertRejects(() => verifyStripeSignature(PAYLOAD, `t=${NOW}`, SECRET), SignatureError)
})

Deno.test('active subscription is premium until period end plus grace', () => {
  const state = premiumStateFor({ id: 'sub_1', customer: 'cus_1', status: 'active', current_period_end: NOW })
  assert(state.isPremium)
  assertEquals(state.premiumUntil, new Date((NOW + RENEWAL_GRACE_SECONDS) * 1000).toISOString())
})

Deno.test('period end is read from items on newer API versions', () => {
  const sub = {
    id: 'sub_1',
    customer: { id: 'cus_1' },
    status: 'trialing',
    items: { data: [{ current_period_end: NOW - 10 }, { current_period_end: NOW }] },
  }
  assertEquals(periodEnd(sub), NOW)
  assert(premiumStateFor(sub).isPremium)
})

Deno.test('past_due keeps premium; canceled, unpaid and incomplete do not', () => {
  const base = { id: 'sub_1', customer: 'cus_1', current_period_end: NOW }
  assert(premiumStateFor({ ...base, status: 'past_due' }).isPremium)
  for (const status of ['canceled', 'unpaid', 'incomplete', 'incomplete_expired', 'paused']) {
    assertEquals(premiumStateFor({ ...base, status }), { isPremium: false, premiumUntil: null })
  }
})

Deno.test('isUuid', () => {
  assert(isUuid('3f2b8c1e-9a4d-4e7f-8b2a-1c3d5e7f9a0b'))
  assert(!isUuid('not-a-uuid'))
  assert(!isUuid(null))
})
