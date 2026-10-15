# Monetization: DuoTask Premium (web) and usage analytics

*Written 2026-10-15. Nothing here is live yet: the migrations aren't applied,
the webhook isn't deployed, and no Stripe product exists.*

## What was built

| Piece | Where |
|---|---|
| Premium columns `users.is_premium`, `users.premium_until`; Stripe IDs in service-role-only `billing_customers`; guard trigger blocking client writes; `get_premium_status()` RPC (one subscription covers the pair) | `supabase/migrations/20261015000001_premium_tier.sql` |
| Stripe webhook (signature-verified; re-reads the subscription from Stripe, so out-of-order and retried events are safe) | `supabase/functions/stripe-webhook/` |
| Usage events, recorded by triggers into private `analytics.events` | `supabase/migrations/20261015000002_usage_events.sql` |
| Premium state in the app | `lib/services/premium_service.dart`, `lib/models/premium_status.dart` |
| Gated feature: Streaks & Stats | `lib/screens/stats_screen.dart`, `lib/utils/pair_stats.dart`, `lib/services/stats_service.dart` |
| Upgrade / Manage subscription | Settings → *DuoTask Premium*; paywall on the stats screen; 🔥 icon in the home app bar |

How a purchase flows:

1. The user taps **Upgrade**. The app opens `STRIPE_PAYMENT_LINK_URL` with
   `?client_reference_id=<their user id>` in the same tab.
2. They pay on Stripe's page. Stripe redirects back to the app (configured on
   the Payment Link) and sends `checkout.session.completed` to the webhook.
3. The webhook verifies the signature, fetches the subscription, stores the
   Stripe IDs in `billing_customers`, and sets `is_premium = true` and
   `premium_until` (the period end plus 2 days of grace for late renewal
   webhooks).
4. Renewals, failed payments and cancellations arrive as
   `customer.subscription.updated` / `.deleted` and update the same row.
5. The app asks `get_premium_status()`, which returns premium if **you or your
   active partner** have a live subscription.

## Go-live

Do these in order. Use Stripe **test mode** and a **staging** Supabase project
first; repeat in live mode for production.

### 0. Prerequisites

- [ ] Finish [CREDENTIAL_ROTATION.md](CREDENTIAL_ROTATION.md) first. The webhook
      runs with the service role, so it shouldn't go live while the old
      `service_role` key still works.
- [ ] **Don't push `main` yet.** `deploy.yml` runs `supabase db push` against
      production on every push. Unpushed commits include `338dac9`
      (`20261014000001_harden_rpc_permissions.sql`) and this work (two more
      migrations).

### 1. Staging Supabase project

- [ ] Create a project, e.g. `duotask-staging`. The same project can serve as
      the CI **test** project that PROJECT_STATUS.md asks for.
- [ ] **Before** `db push`, add the Vault secrets in the SQL editor (new
      projects already have the `supabase_vault` extension):
      ```sql
      select vault.create_secret('https://<staging-ref>.supabase.co', 'project_url');
      select vault.create_secret('<staging anon key>', 'anon_key');
      ```
      Which migrations depend on them:
      - `20250625000005_setup_email_cron.sql` and
        `20260828000002_email_cron_hourly.sql` **fail** without them (they
        raise before scheduling the email cron job), and `db push` stops there.
      - `20260917000001_device_tokens_and_nudge_push.sql` reads them at
        runtime only; without them the nudge-push trigger skips the HTTP call.
      - Every other migration, including the two Premium/analytics ones,
        doesn't use Vault.
- [ ] Apply the migrations:
      ```bash
      supabase link --project-ref <staging-ref>
      supabase db push
      ```
      The baseline used to fail on an empty database (`tasks` referenced
      `pairings` before it was created). That's fixed: `pairings` is now
      created first, and the resulting schema is identical. The
      full chain was verified on 2026-10-15 against an empty local Postgres 14
      with stubbed `auth`/`vault`/`cron`/`net`: all 13 migrations apply with
      the secrets set; without them, only the two cron migrations fail.
- [ ] Check the new objects exist: `select * from get_premium_status();` fails
      with "Not authenticated" in the SQL editor (expected), and
      `select count(*) from analytics.events;` returns the backfill.

### 2. Stripe product and links (test mode)

- [ ] **Product catalog → Add product**: "DuoTask Premium", with a recurring price
      (for example $2.99/month, and optionally $24/year). The price is your
      call; the code doesn't hardcode it.
- [ ] **Payment Links → New**: pick the price, then under *After payment*
      choose **Don't show confirmation page → redirect to** your app URL
      (staging URL for test mode,
      `https://duotask.namasteneedham.com/` for live). Copy the link
      (`https://buy.stripe.com/test_…`).
- [ ] **Settings → Billing → Customer portal**: enable it, allow cancellation,
      and copy the **login link** (`https://billing.stripe.com/p/login/test_…`).
- [ ] **Settings → Public details**: add a support email and your Terms/Privacy
      URLs. Live-mode checkout requires them.

### 3. Webhook and secrets

- [ ] **Developers → Webhooks → Add endpoint**:
      `https://<ref>.supabase.co/functions/v1/stripe-webhook`, with events
      `checkout.session.completed`, `customer.subscription.updated`,
      `customer.subscription.deleted`. Copy the signing secret (`whsec_…`).
- [ ] **Developers → API keys → Create restricted key**: *Subscriptions: Read*,
      everything else None. Copy it (`rk_test_…`).
- [ ] Set the function secrets and deploy (functions aren't deployed by CI):
      ```bash
      supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_... STRIPE_SECRET_KEY=rk_test_... --project-ref <ref>
      ```
      ```bash
      supabase functions deploy stripe-webhook --no-verify-jwt --project-ref <ref>
      ```

### 4. Test end to end on staging

- [ ] Build the web app against staging with the test links
      (`STRIPE_PAYMENT_LINK_URL` and `STRIPE_CUSTOMER_PORTAL_URL` in `.env`,
      then `scripts/build_web.sh`, or `flutter run -d chrome` with
      `--dart-define`s).
- [ ] Sign up two users and pair them. User A taps **Upgrade** and pays with
      card `4242 4242 4242 4242`.
- [ ] In Stripe → the webhook endpoint, the event shows **200**. In SQL,
      `select is_premium, premium_until from users` shows A as premium.
- [ ] A and B **both** see Streaks & Stats unlocked (B via partner).
- [ ] With B's session, try to self-grant, e.g. in the SQL editor:
      `set local role authenticated; select set_config('request.jwt.claims', '{"sub":"<B id>","role":"authenticated"}', true); update users set is_premium = true where id = '<B id>';`
      It must fail with "Billing fields are managed by the server".
- [ ] Cancel A's subscription in the Stripe dashboard (*cancel immediately*).
      `is_premium` flips to false and both users see the paywall again.
- [ ] Send a webhook with a wrong secret (e.g. `curl -X POST` to the URL). It
      returns **400**.
- [ ] `deno test supabase/functions/stripe-webhook/stripe_test.ts` passes.

### 5. Production

- [ ] Repeat §2 and §3 in **live mode** against the production project
      (separate product, Payment Link, portal link, webhook secret and
      restricted key; live keys never go on staging).
- [ ] GitHub → Settings → Secrets and variables → Actions → **Variables** tab:
      `STRIPE_PAYMENT_LINK_URL`, `STRIPE_CUSTOMER_PORTAL_URL` (public URLs, not
      secrets). Without them the upgrade button reads "Premium is coming soon."
- [ ] Review `assets/docs/privacy_policy.md` (updated for usage events and
      Stripe) and add refund/cancellation terms to `terms_of_service.md`.
- [ ] Mark the baseline as applied on production **before** the first push.
      Production was provisioned by hand and CI's `db push` has never run
      there, so its migration history probably lacks `00000000000000`:
      ```bash
      supabase link --project-ref <production-ref>
      supabase migration list        # check what the remote already records
      supabase migration repair --status applied 00000000000000
      ```
      Without this, `db push` stops at the baseline's guard ("Baseline schema
      already present"). The guard is there because re-running the baseline on
      a migrated database would silently revert the RPC hardening and re-grant
      `anon` access to `billing_customers` and other locked-down tables.
      `migration list` may also show other hand-applied migrations missing
      from the remote; repair those the same way once you've confirmed they're
      really in the live schema.
- [ ] Push `main`. `deploy.yml` applies the three pending migrations and
      deploys the web build. Watch the `supabase migration list` output in the
      *Apply database migrations* step.
- [ ] Make one real purchase yourself, then refund it in Stripe.

## Measuring usage

`analytics.events` isn't reachable through the API. Query it in the Supabase
SQL editor. Rows marked `props->>'backfill' = 'true'` were reconstructed from
existing data when the migration ran.

Weekly signups, pairings and completions:

```sql
select date_trunc('week', created_at) as week,
       count(*) filter (where event = 'signup')         as signups,
       count(*) filter (where event = 'pair_created')   as pairs,
       count(*) filter (where event = 'task_completed') as completions,
       count(distinct user_id)                          as active_users
from analytics.events
group by 1 order by 1 desc;
```

Activation, the share of signups who pair and complete a task within 7 days:

```sql
with s as (select user_id, created_at from analytics.events where event = 'signup')
select date_trunc('week', s.created_at) as cohort,
       count(*) as signups,
       count(*) filter (where exists (select 1 from analytics.events e
         where e.user_id = s.user_id and e.event = 'pair_created'
           and e.created_at < s.created_at + interval '7 days'))   as paired_7d,
       count(*) filter (where exists (select 1 from analytics.events e
         where e.user_id = s.user_id and e.event = 'task_completed'
           and e.created_at < s.created_at + interval '7 days'))   as completed_7d
from s group by 1 order by 1 desc;
```

Week-1 retention, the share of signups active in days 7–13:

```sql
with s as (select user_id, created_at from analytics.events where event = 'signup')
select date_trunc('week', s.created_at) as cohort,
       count(*) as signups,
       round(100.0 * count(*) filter (where exists (select 1 from analytics.events e
         where e.user_id = s.user_id and e.event <> 'signup'
           and e.created_at >= s.created_at + interval '7 days'
           and e.created_at <  s.created_at + interval '14 days')) / count(*), 1) as w1_retained_pct
from s group by 1 order by 1 desc;
```

Premium conversions:

```sql
select date_trunc('month', created_at) as month,
       count(*) filter (where event = 'premium_started') as started,
       count(*) filter (where event = 'premium_ended')   as ended
from analytics.events group by 1 order by 1 desc;
```

Things to know:

- `task_created` includes the next occurrence that's auto-created when a
  recurring task is completed. Filter on `props->>'recurrence' = 'none'` for
  user-initiated tasks only.
- Undoing a completion logs `task_uncompleted`. Subtract it for net
  completions.
- "Active" means doing something that writes (task, completion, nudge,
  pairing). Merely opening the app isn't recorded. For page-view and visitor
  numbers, enable **Vercel Web Analytics** (cookieless) on the project in the
  Vercel dashboard. It needs a one-line script tag in `web/index.html`, which
  isn't added yet.
