// Run with: deno test supabase/functions/lifecycle-emails/templates_test.ts
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { escapeHtml, firstName, formatDay, type LifecycleEmailRow, renderLifecycleEmail } from './templates.ts'

const APP = 'https://duotask.example.com'

function row(over: Partial<LifecycleEmailRow> = {}): LifecycleEmailRow {
  return {
    email_id: 1,
    user_id: 'u1',
    kind: 'invite_partner',
    email: 'sam@example.com',
    display_name: 'Sam Rivera',
    partner_name: null,
    timezone: 'America/New_York',
    trial_ends_at: null,
    ...over,
  }
}

Deno.test('escapeHtml escapes markup and quotes', () => {
  assertEquals(escapeHtml(`<a href="x">'&'</a>`), '&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;')
})

Deno.test('firstName takes the first word and handles blanks', () => {
  assertEquals(firstName('  Sam   Rivera '), 'Sam')
  assertEquals(firstName(''), null)
  assertEquals(firstName(null), null)
  assertEquals(firstName('x'.repeat(60))?.length, 40)
})

Deno.test('a display name cannot inject HTML', () => {
  const e = renderLifecycleEmail(row({ display_name: '<img src=x onerror=alert(1)>' }), APP)
  assert(!e.html.includes('<img'))
  assert(e.html.includes('&lt;img'))
})

Deno.test('invite_partner greets by first name and links to the app', () => {
  const e = renderLifecycleEmail(row(), APP)
  assertEquals(e.subject, 'DuoTask works best with two')
  assert(e.text.startsWith('Hi Sam,'))
  assert(e.text.includes('Pair Now'))
  assert(e.html.includes(`href="${APP}"`))
  assert(e.text.includes('Tips and reminders'), 'says how to opt out')
})

Deno.test('no name: a plain greeting', () => {
  const e = renderLifecycleEmail(row({ display_name: null }), APP)
  assert(e.text.startsWith('Hi,'))
})

Deno.test('tips names the partner when paired, and suggests share links when not', () => {
  const paired = renderLifecycleEmail(row({ kind: 'tips', partner_name: 'Alex Kim' }), APP)
  assert(paired.text.includes('so Alex can see'))
  const solo = renderLifecycleEmail(row({ kind: 'tips' }), APP)
  assert(solo.text.includes('Send a task to anyone by link'))
  assertEquals(solo.subject, '3 things that make DuoTask easier')
})

Deno.test('trial_ending gives the end day in the user timezone, with no opt-out line', () => {
  // 03:00 UTC on Nov 20 is still Nov 19 in New York.
  const e = renderLifecycleEmail(
    row({ kind: 'trial_ending', trial_ends_at: '2026-11-20T03:00:00Z' }),
    APP,
  )
  assertEquals(e.subject, 'Your DuoTask Premium trial ends Thursday, November 19')
  assert(e.text.includes('Manage subscription'))
  assert(!e.text.includes('Tips and reminders'))
})

Deno.test('formatDay falls back to UTC for an unknown timezone', () => {
  assertEquals(formatDay('2026-11-20T03:00:00Z', 'Not/AZone'), 'Friday, November 20')
})
