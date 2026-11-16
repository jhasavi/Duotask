// Lifecycle email content. Pure functions (no Deno or network APIs) so they
// can be unit tested anywhere: see templates_test.ts.

export type LifecycleKind = 'invite_partner' | 'tips' | 'trial_ending'

/** One row from the claim_lifecycle_emails RPC. */
export interface LifecycleEmailRow {
  email_id: number
  user_id: string
  kind: LifecycleKind
  email: string
  display_name: string | null
  partner_name: string | null
  timezone: string | null
  trial_ends_at: string | null
}

export interface RenderedEmail {
  subject: string
  html: string
  text: string
}

export function escapeHtml(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

/** First name for a greeting, or null. Display names are free text. */
export function firstName(displayName: string | null | undefined): string | null {
  const first = (displayName ?? '').trim().split(/\s+/)[0]
  if (!first) return null
  return first.length > 40 ? first.slice(0, 40) : first
}

/** "Thursday, November 19" in the user's timezone (UTC if unknown). */
export function formatDay(iso: string, timeZone: string | null): string {
  const date = new Date(iso)
  const opts: Intl.DateTimeFormatOptions = { weekday: 'long', month: 'long', day: 'numeric' }
  try {
    return new Intl.DateTimeFormat('en-US', { ...opts, timeZone: timeZone || 'UTC' }).format(date)
  } catch {
    return new Intl.DateTimeFormat('en-US', { ...opts, timeZone: 'UTC' }).format(date)
  }
}

interface Content {
  subject: string
  heading: string
  paragraphs: string[] // plain text; escaped when rendered
  bullets?: string[]
  cta: string
  optOutNote: boolean // invite_partner and tips can be turned off
}

function content(row: LifecycleEmailRow): Content {
  const partner = firstName(row.partner_name)
  switch (row.kind) {
    case 'invite_partner':
      return {
        subject: 'DuoTask works best with two',
        heading: 'Invite your partner',
        paragraphs: [
          "DuoTask is a to-do list for two people, and it really starts working once the other person is on it: you can see who's taking care of what, without asking.",
          "Open DuoTask, tap Pair Now, and send them a link by WhatsApp, text or email. They tap it, sign up, and you're paired. It takes about a minute.",
        ],
        cta: 'Invite your partner',
        optOutNote: true,
      }
    case 'tips':
      return {
        subject: '3 things that make DuoTask easier',
        heading: 'Three small things worth knowing',
        paragraphs: [],
        bullets: [
          'Type tasks the way you\'d say them. "Pick up dry cleaning tomorrow @6pm urgent" gets the right due date and priority.',
          'Make chores repeat. Set a task to daily or weekly once, and it comes back by itself after it\'s done.',
          partner
            ? `Claim a task when you take it on, so ${partner} can see you've got it.`
            : "Send a task to anyone by link. They can say \"I'll do it\" without the app.",
        ],
        cta: 'Open DuoTask',
        optOutNote: true,
      }
    case 'trial_ending': {
      const day = row.trial_ends_at ? formatDay(row.trial_ends_at, row.timezone) : 'soon'
      return {
        subject: `Your DuoTask Premium trial ends ${day}`,
        heading: 'Your Premium trial is ending',
        paragraphs: [
          `Your free trial of DuoTask Premium ends on ${day}. If you keep it, your subscription starts then and Stripe charges the card you added. You and your partner both keep Premium.`,
          "To cancel instead, open DuoTask, go to Settings and choose Manage subscription before the trial ends. You won't be charged.",
        ],
        cta: 'Manage subscription',
        optOutNote: false,
      }
    }
  }
}

export function renderLifecycleEmail(row: LifecycleEmailRow, appUrl: string): RenderedEmail {
  const c = content(row)
  const name = firstName(row.display_name)
  const greeting = name ? `Hi ${name},` : 'Hi,'
  const footer = c.optOutNote
    ? "You're getting this because you recently joined DuoTask. To stop these emails, turn off \"Tips and reminders\" in DuoTask's Settings."
    : "You're getting this because you started a DuoTask Premium trial."

  const text = [
    greeting,
    '',
    ...c.paragraphs.flatMap((p) => [p, '']),
    ...(c.bullets ?? []).map((b) => `- ${b}`),
    ...(c.bullets ? [''] : []),
    `${c.cta}: ${appUrl}`,
    '',
    '--',
    footer,
  ].join('\n')

  const p = (t: string) =>
    `<p style="margin:0 0 16px 0;color:#374151;font-size:16px;line-height:1.5;">${escapeHtml(t)}</p>`
  const bullets = c.bullets
    ? `<ul style="margin:0 0 16px 0;padding-left:20px;color:#374151;font-size:16px;line-height:1.5;">${
      c.bullets.map((b) => `<li style="margin-bottom:8px;">${escapeHtml(b)}</li>`).join('')
    }</ul>`
    : ''

  const html = `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${escapeHtml(c.subject)}</title></head>
<body style="margin:0;padding:24px 16px;background:#f9fafb;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <div style="max-width:560px;margin:0 auto;background:#ffffff;border-radius:12px;padding:32px 24px;">
    <h1 style="margin:0 0 20px 0;color:#111827;font-size:22px;">${escapeHtml(c.heading)}</h1>
    ${p(greeting)}
    ${c.paragraphs.map(p).join('\n    ')}
    ${bullets}
    <p style="margin:24px 0;">
      <a href="${escapeHtml(appUrl)}" style="display:inline-block;background:#6366f1;color:#ffffff;text-decoration:none;padding:12px 20px;border-radius:8px;font-weight:600;">${escapeHtml(c.cta)}</a>
    </p>
  </div>
  <p style="max-width:560px;margin:16px auto 0;color:#6b7280;font-size:12px;line-height:1.5;text-align:center;">${escapeHtml(footer)}</p>
</body>
</html>`

  return { subject: c.subject, html, text }
}
