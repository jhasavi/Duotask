// Supabase Edge Function: lifecycle-emails
//
// Sends the onboarding and trial emails that are due right now. Who is due,
// and when, is decided in the database (claim_lifecycle_emails in
// 20261115000003_lifecycle_emails.sql); this function only renders and sends.
// Called hourly by the 'lifecycle-emails' pg_cron job.
//
// Deploy:  supabase functions deploy lifecycle-emails
// Secrets: RESEND_API_KEY (required)
//          EMAIL_FROM  e.g. 'EvenHalf <hello@yourdomain.com>' on a domain
//                      verified in Resend. Resend's shared test sender only
//                      delivers to the Resend account owner.
//          APP_URL     defaults to https://duotask.namasteneedham.com

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { type LifecycleEmailRow, renderLifecycleEmail } from './templates.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const EMAIL_FROM = Deno.env.get('EMAIL_FROM') || 'EvenHalf <onboarding@resend.dev>'
const APP_URL = Deno.env.get('APP_URL') || 'https://duotask.namasteneedham.com'
// Overridable so a test can point it at a stub.
const RESEND_URL = Deno.env.get('RESEND_URL') || 'https://api.resend.com/emails'

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })

serve(async () => {
  // Claim nothing we can't send, or the claims would sit as failures.
  if (!RESEND_API_KEY) return json({ error: 'RESEND_API_KEY is not set' }, 500)

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
  const { data, error } = await supabase.rpc('claim_lifecycle_emails', { p_limit: 100 })
  if (error) {
    console.error('claim_lifecycle_emails failed:', error)
    return json({ error: error.message }, 500)
  }

  const rows = (data ?? []) as LifecycleEmailRow[]
  let sent = 0
  let failed = 0

  for (const row of rows) {
    let ok = false
    try {
      const email = renderLifecycleEmail(row, APP_URL)
      const res = await fetch(RESEND_URL, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: EMAIL_FROM,
          to: [row.email],
          subject: email.subject,
          html: email.html,
          text: email.text,
          tags: [{ name: 'kind', value: row.kind }],
        }),
      })
      ok = res.ok
      if (!ok) console.error(`Resend refused ${row.kind} #${row.email_id}:`, await res.text())
    } catch (e) {
      console.error(`Sending ${row.kind} #${row.email_id} failed:`, e)
    }

    const { error: finishError } = await supabase.rpc('finish_lifecycle_email', {
      p_email_id: row.email_id,
      p_sent: ok,
    })
    if (finishError) console.error(`finish_lifecycle_email #${row.email_id}:`, finishError)
    ok ? sent++ : failed++
  }

  return json({ claimed: rows.length, sent, failed })
})
