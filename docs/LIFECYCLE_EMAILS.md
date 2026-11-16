# Lifecycle emails

*Built 2026-11-15. Not live: it ships with the next push of `main`, and needs
the setup below before anything sends.*

Three emails, each sent at most once per user:

| Email | When | Why |
|---|---|---|
| **Invite your partner** | 1–7 days after sign-up, while still unpaired | Pairing is what makes DuoTask useful; signups who never pair never come back |
| **3 tips** | 3–14 days after sign-up | Natural-language input, repeating chores, and claiming (or send-by-link if unpaired) |
| **Trial ending** | Within 3 days of a Premium trial converting | Fair warning before Stripe charges; reduces refunds and chargebacks |

To preview the wording with sample data, open `docs/lifecycle-email-preview.html`
in a browser (generated from the templates; safe to delete).

## Rules

All enforced in the database (`claim_lifecycle_emails`,
[20261115000003_lifecycle_emails.sql](../supabase/migrations/20261115000003_lifecycle_emails.sql)):

- Sent only between 09:00 and 19:59 in the user's timezone (the one the app
  stores for the daily digest).
- At most one lifecycle email per user per run, none within 20 hours of the
  previous one. Priority: trial ending, invite, tips.
- **Existing users get nothing.** The sign-up windows are relative to now, so
  everyone who signed up more than 14 days before this ships is outside them.
- Settings → *Tips and reminders* turns off the invite and tips emails. The
  trial notice is a billing email and is always sent.
- Two overlapping runs can't send the same email (a unique claim per user and
  email). A failed send is retried on the next hourly run, at most 3 times.

## Pieces

- `supabase/functions/lifecycle-emails/`: `index.ts` claims, sends through
  Resend, and reports back; `templates.ts` is the content (names are
  HTML-escaped). Tests: `templates_test.ts`.
- pg_cron job `lifecycle-emails`, every hour at :15.
- `lifecycle_emails` table: one row per user and email, with status and
  attempts.
- Usage event `lifecycle_email_sent` with `props.kind`.

## Setup (owner)

1. **Verify a sending domain in Resend** (for example `namasteneedham.com`)
   and pick a from address such as `DuoTask <hello@namasteneedham.com>`.
   Resend's shared `onboarding@resend.dev` sender only delivers to the Resend
   account owner. **The existing daily digest uses that sender today**, so it
   is probably not reaching users either.
2. Set the function secrets, using the rotated Resend key:
   ```bash
   supabase secrets set RESEND_API_KEY=re_... EMAIL_FROM='DuoTask <hello@namasteneedham.com>' APP_URL=https://duotask.namasteneedham.com
   ```
3. Deploy: `supabase functions deploy lifecycle-emails`
4. The migration creates the cron job; it needs the same Vault secrets
   (`project_url`, `anon_key`) as the digest.
5. Watch the first runs in *Edge Functions → lifecycle-emails → Logs*. Each
   run returns `{claimed, sent, failed}`.

## Measuring

```sql
select props->>'kind' as kind,
       count(*) as sent,
       count(*) filter (where props->>'kind' = 'invite_partner' and exists (
         select 1 from analytics.events p
         where p.event = 'pair_created' and p.user_id = e.user_id
           and p.created_at between e.created_at and e.created_at + interval '7 days'
       )) as paired_within_7d_after_invite
from analytics.events e
where event = 'lifecycle_email_sent'
group by 1;
```

`pair_created` is attributed to whoever completed the pairing, so a partner
who joins *your* code counts for them, not you. Treat the number as a trend.

## How it was tested

- Integration tests against a local stack (`test/integration/lifecycle_emails_test.dart`):
  email chosen by age and pairing, old and brand-new users skipped, never
  sent twice, the 20-hour gap, retries capped at 3, overlapping runs,
  daytime only, opt-out vs. trial notice, clients can't call the RPC.
- Template tests run under Node through esbuild (Deno isn't installed here):
  greeting, partner name, HTML injection, timezone-correct trial date.
- **Not run:** the edge function itself end to end (needs the Supabase edge
  runtime and a Resend key). Do one real send to yourself after setup.

## Known limits

- The cron calls the function with the legacy JWT anon key, like the digest.
  If you move to Supabase's new publishable keys, both cron jobs need a key
  the function gateway accepts.
- Anyone with the anon key can trigger a run, but it only sends emails that
  are already due, once each.
- No unsubscribe link that works without signing in; the footer points to
  Settings. Fine for onboarding email to your own users; add a one-click
  link before sending anything promotional.
