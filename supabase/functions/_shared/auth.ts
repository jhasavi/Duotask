// Shared auth for edge functions.
//
// Supabase's new API keys (sb_publishable_ / sb_secret_) are not JWTs, so the
// gateway's verify_jwt check cannot be used with them. Functions called by
// pg_cron or database triggers set `verify_jwt = false` in config.toml and
// check a shared secret here instead. The caller sends it as
// `Authorization: Bearer <FUNCTION_AUTH_SECRET>`; in the database it is stored
// in the Vault secret `anon_key` (the name is historical).
//
// Secrets: FUNCTION_AUTH_SECRET  long random string, required (fails closed)
//          SB_SECRET_KEY         the project's sb_secret_ key; falls back to
//                                the platform's SUPABASE_SERVICE_ROLE_KEY

export const SERVICE_KEY: string =
  Deno.env.get('SB_SECRET_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder()
  const x = enc.encode(a)
  const y = enc.encode(b)
  let diff = x.length ^ y.length
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    diff |= (x[i] ?? 0) ^ (y[i] ?? 0)
  }
  return diff === 0
}

/** True when the request carries the correct shared secret. */
export function isAuthorized(req: Request): boolean {
  const expected = Deno.env.get('FUNCTION_AUTH_SECRET') ?? ''
  if (expected.length < 32) return false // unset or too short: fail closed
  const header = req.headers.get('Authorization') ?? ''
  const m = header.match(/^Bearer (.+)$/)
  return m != null && safeEqual(m[1], expected)
}

export const unauthorized = () =>
  new Response(JSON.stringify({ error: 'unauthorized' }), {
    status: 401,
    headers: { 'Content-Type': 'application/json' },
  })
