// Supabase Edge Function: send-nudge-push
//
// Invoked by the `trg_notify_nudge_push` trigger (see
// supabase/migrations/20260917000001_device_tokens_and_nudge_push.sql)
// immediately after a row is inserted into `nudges`. Looks up every device
// token the recipient has registered and delivers an FCM push to each.
//
// FCM's legacy server-key API is retired; this uses the v1 HTTP API, which
// requires a short-lived OAuth2 access token obtained by signing a JWT with
// a Firebase service account's private key (RS256). Deploy with:
//   supabase functions deploy send-nudge-push
//
// Required Supabase Vault secret: `firebase_service_account`, the full JSON
// contents of a Firebase service account key with the
// "Firebase Cloud Messaging API" role. See docs/PUSH_NOTIFICATIONS_SETUP.md.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

interface ServiceAccount {
  project_id: string
  client_email: string
  private_key: string
}

interface DeviceToken {
  id: string
  token: string
}

function base64UrlEncode(data: Uint8Array | string): string {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}

// Exchanges a Firebase service account for a short-lived FCM access token by
// self-signing a JWT (RFC 7523) and trading it at Google's OAuth2 endpoint.
async function getAccessToken(account: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const claims = {
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }

  const unsigned = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(JSON.stringify(claims))}`

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  )
  const jwt = `${unsigned}.${base64UrlEncode(new Uint8Array(signature))}`

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  if (!response.ok) {
    throw new Error(`Failed to obtain FCM access token: ${await response.text()}`)
  }

  const { access_token } = await response.json()
  return access_token
}

serve(async (req) => {
  try {
    const { nudge_id } = await req.json()
    if (!nudge_id) {
      return new Response(JSON.stringify({ error: 'nudge_id is required' }), { status: 400 })
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    const { data: nudge, error: nudgeError } = await supabase
      .from('nudges')
      .select('id, message, task_id, to_user_id')
      .eq('id', nudge_id)
      .single()

    if (nudgeError || !nudge) {
      throw nudgeError ?? new Error(`Nudge ${nudge_id} not found`)
    }

    const { data: tokens, error: tokensError } = await supabase
      .from('device_tokens')
      .select('id, token')
      .eq('user_id', nudge.to_user_id)

    if (tokensError) throw tokensError

    if (!tokens || tokens.length === 0) {
      // Recipient has no registered devices (web-only user, or never granted
      // notification permission). Not an error — they'll still see the nudge
      // in-app via Realtime.
      return new Response(JSON.stringify({ sent: 0, reason: 'no device tokens' }), { status: 200 })
    }

    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountJson) {
      console.error('FIREBASE_SERVICE_ACCOUNT secret is not set; cannot send push.')
      return new Response(JSON.stringify({ sent: 0, reason: 'push not configured' }), { status: 200 })
    }
    const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson)

    const accessToken = await getAccessToken(serviceAccount)
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`

    let sent = 0
    const staleTokenIds: string[] = []

    for (const deviceToken of tokens as DeviceToken[]) {
      const response = await fetch(fcmUrl, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: deviceToken.token,
            notification: {
              title: 'DuoTask',
              body: nudge.message,
            },
            data: {
              type: 'nudge',
              nudge_id: nudge.id,
              task_id: nudge.task_id ?? '',
            },
          },
        }),
      })

      if (response.ok) {
        sent++
      } else {
        const errorBody = await response.text()
        // UNREGISTERED / NOT_FOUND means the app was uninstalled or the token
        // rotated without us hearing about it — clean it up so future nudges
        // don't keep retrying a dead token.
        if (errorBody.includes('UNREGISTERED') || errorBody.includes('NOT_FOUND')) {
          staleTokenIds.push(deviceToken.id)
        } else {
          console.error(`FCM send failed for token ${deviceToken.id}:`, errorBody)
        }
      }
    }

    if (staleTokenIds.length > 0) {
      await supabase.from('device_tokens').delete().in('id', staleTokenIds)
    }

    return new Response(
      JSON.stringify({ sent, failed: tokens.length - sent, removed_stale: staleTokenIds.length }),
      { headers: { 'Content-Type': 'application/json' }, status: 200 },
    )
  } catch (error) {
    console.error('Error in send-nudge-push function:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
