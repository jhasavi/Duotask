// Supabase Edge Function: stripe-webhook
//
// Receives Stripe webhook events and keeps users.is_premium /
// users.premium_until in sync with the payer's subscription. One paid
// subscription covers the pair: public.get_premium_status() also reports the
// partner of a paying user as premium.
//
// Handled events:
//   checkout.session.completed      links the Stripe customer to a DuoTask
//                                   user (via the Payment Link's
//                                   client_reference_id) and turns premium on
//   customer.subscription.updated   renewals, cancel-at-period-end, failures
//   customer.subscription.deleted   turns premium off
//
// Stripe can deliver events late and out of order, so the handler never
// trusts the subscription snapshot in the event body: it re-reads the
// subscription from the Stripe API and writes that state. Every write is
// therefore idempotent and safe to retry.
//
// Stripe does not send a Supabase JWT, so this function must be deployed
// with JWT verification off (see [functions.stripe-webhook] in
// supabase/config.toml); the Stripe signature check below replaces it.
//
//   supabase functions deploy stripe-webhook --no-verify-jwt
//
// Required secrets (supabase secrets set ...):
//   STRIPE_WEBHOOK_SECRET  whsec_... from the webhook endpoint in Stripe
//   STRIPE_SECRET_KEY      a restricted key with Subscriptions: Read
// See docs/MONETIZATION.md.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  customerId,
  isUuid,
  premiumStateFor,
  SignatureError,
  StripeSubscription,
  verifyStripeSignature,
} from './stripe.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const STRIPE_WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? ''
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY') ?? ''

// Stripe object ids (sub_..., cus_...); checked before they go into a
// PostgREST filter string.
const STRIPE_ID_RE = /^[A-Za-z0-9_]+$/

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

async function fetchSubscription(id: string): Promise<StripeSubscription> {
  const res = await fetch(`https://api.stripe.com/v1/subscriptions/${encodeURIComponent(id)}`, {
    headers: { Authorization: `Bearer ${STRIPE_SECRET_KEY}` },
  })
  if (!res.ok) {
    throw new Error(`Stripe subscription lookup failed: ${res.status} ${await res.text()}`)
  }
  return await res.json()
}

/** Writes the subscription's state onto the user's row and billing record. */
async function applySubscription(
  supabase: SupabaseClient,
  userId: string,
  sub: StripeSubscription,
): Promise<void> {
  const state = premiumStateFor(sub)

  const { error: billingError } = await supabase.from('billing_customers').upsert(
    {
      user_id: userId,
      stripe_customer_id: customerId(sub),
      stripe_subscription_id: sub.id,
      subscription_status: sub.status,
    },
    { onConflict: 'user_id' },
  )
  if (billingError) throw billingError

  const { error: userError } = await supabase
    .from('users')
    .update({ is_premium: state.isPremium, premium_until: state.premiumUntil })
    .eq('id', userId)
  if (userError) throw userError

  console.log(`user ${userId}: subscription ${sub.id} ${sub.status} -> premium=${state.isPremium}`)
}

async function handleCheckoutCompleted(
  supabase: SupabaseClient,
  session: Record<string, any>,
): Promise<Response> {
  if (session.mode !== 'subscription' || !session.subscription) {
    return json({ ignored: 'not a subscription checkout' })
  }

  let userId: string | null = isUuid(session.client_reference_id)
    ? session.client_reference_id
    : null

  // Fallback for a Payment Link opened without ?client_reference_id (e.g.
  // shared by URL): match the checkout email to an account.
  const email: string | undefined = session.customer_details?.email ?? session.customer_email
  if (!userId && email) {
    const { data } = await supabase
      .from('users')
      .select('id')
      .eq('email', email.toLowerCase())
      .maybeSingle()
    userId = data?.id ?? null
  }

  if (!userId) {
    // Not retryable: Stripe would just redeliver the same payload. Shows up
    // in the function logs and in Stripe's event view for manual linking.
    console.error(`checkout ${session.id}: no matching DuoTask user`)
    return json({ ignored: 'no matching user' })
  }

  const subscriptionId =
    typeof session.subscription === 'string' ? session.subscription : session.subscription.id
  await applySubscription(supabase, userId, await fetchSubscription(subscriptionId))
  return json({ received: true })
}

async function handleSubscriptionEvent(
  supabase: SupabaseClient,
  eventSub: StripeSubscription,
): Promise<Response> {
  const customer = customerId(eventSub)
  if (!STRIPE_ID_RE.test(eventSub.id) || !STRIPE_ID_RE.test(customer)) {
    return json({ ignored: 'malformed ids' })
  }

  const { data: billing, error } = await supabase
    .from('billing_customers')
    .select('user_id')
    .or(`stripe_subscription_id.eq.${eventSub.id},stripe_customer_id.eq.${customer}`)
    .limit(1)
    .maybeSingle()
  if (error) throw error

  if (!billing) {
    // The subscription events for a new checkout can arrive before
    // checkout.session.completed; that handler fetches the same
    // subscription, so nothing is lost by skipping here.
    return json({ ignored: 'unknown subscription' })
  }

  const latest = await fetchSubscription(eventSub.id)
  await applySubscription(supabase, billing.user_id, latest)
  return json({ received: true })
}

serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405)

  const payload = await req.text()
  try {
    await verifyStripeSignature(payload, req.headers.get('stripe-signature'), STRIPE_WEBHOOK_SECRET)
  } catch (e) {
    if (e instanceof SignatureError) {
      console.warn(`rejected webhook: ${e.message}`)
      return json({ error: 'invalid signature' }, 400)
    }
    throw e
  }

  if (!STRIPE_SECRET_KEY) {
    console.error('STRIPE_SECRET_KEY is not set')
    return json({ error: 'not configured' }, 500)
  }

  const event = JSON.parse(payload)
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

  try {
    switch (event.type) {
      case 'checkout.session.completed':
        return await handleCheckoutCompleted(supabase, event.data.object)
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted':
        return await handleSubscriptionEvent(supabase, event.data.object)
      default:
        return json({ ignored: event.type })
    }
  } catch (e) {
    // 5xx makes Stripe retry with backoff for up to three days.
    console.error(`event ${event.id} (${event.type}) failed:`, e)
    return json({ error: 'processing failed' }, 500)
  }
})
