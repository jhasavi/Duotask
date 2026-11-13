# DuoTask: next steps and monetization plan

*Written 2026-10-15. One ordered list to pick up from any machine. Detailed
runbooks are linked rather than repeated.*

## Where things stand

- **Live:** web app at `https://duotask.namasteneedham.com`, Flutter + Supabase.
  No revenue yet.
- **Built, not live:** Premium tier via Stripe (one subscription covers both
  partners), the Streaks & Stats premium screen, and the `analytics.events`
  usage table. See [MONETIZATION.md](MONETIZATION.md).
- **Not on GitHub `main`:** commits `338dac9` through `ec815ce` (RPC
  hardening, credential checklist, Premium, two baseline-migration fixes).
  They're on the `macmini-sync` branch so the Mac mini can pick them up.
  **Pushing `main` deploys to production** (`deploy.yml` runs
  `supabase db push`), so don't push `main` until Phase 0 is done.
- **CI deploys have never succeeded.** All runs fail at the secrets preflight,
  so production's schema has only ever been changed by hand.

## 🔴 Production is probably broken for some features right now

`supabase migration list` against production (2026-10-15) shows that the
remote history records **none** of the 13 local migrations (16 since 2026-10-16). It does record
three migrations with no local file: `20250828152200`, `…152300`, `…152400`.

A read-only schema dump of production's `public` schema showed:

| Migration | In production? |
|---|---|
| `00000000000000` baseline (users, tasks, pairings) | Yes (applied by hand) |
| `20250625000001`–`04` (pairing, nudges, email preferences) | Yes, by table presence |
| `20250625000005` daily email cron | Unknown: check `select * from cron.job;` |
| `20260828000001` email timezone column | **No** |
| `20260828000002` hourly email cron | Unknown: same check |
| `20260828000003` task tags and recurrence | **No** (`tags` column missing) |
| `20260917000001` device tokens and nudge push | **No** |
| `20261014000001` RPC hardening | No (expected; not pushed) |
| `20261015000001`/`02` Premium and analytics | No (expected; not pushed) |

The web bundle deployed on 2026-09-16 was built from code that uses tags,
recurrence and timezone, so **those features likely fail for live users.**
Check this first: create a task with a tag on the live site and look for an
error.

## Phase 0: Make production safe and consistent (do first, about a day)

1. **Rotate the leaked credentials.** Resend, Discord, Vercel and Supabase JWT
   keys were public and are still in git history. Follow
   [CREDENTIAL_ROTATION.md](CREDENTIAL_ROTATION.md) in order. Payments must
   not go live while the old `service_role` key works.
2. **Reconcile production's migration history.** Don't push `main` until
   this is done.
   ```bash
   supabase link --project-ref xqhlnuvpogiolzkucupt
   supabase migration list
   ```
   - Fetch the three remote-only migrations into local files so the history
     matches: `supabase migration fetch` (review what it writes before
     committing).
   - In the SQL editor, run `select jobname, schedule from cron.job;`. If
     `daily-email-digest` exists, `20250625000005` is in production; if its
     schedule is `0 * * * *`, so is `20260828000002`.
   - Mark only what's really in production as applied, for example:
     ```bash
     supabase migration repair --status applied 00000000000000 20250625000001 20250625000002 20250625000003 20250625000004
     ```
     Add `20250625000005` and `20260828000002` only if the cron check
     confirms them.
   - The baseline now refuses to run on a database that already has
     `public.users`, so a missed repair fails loudly instead of reverting
     the schema.
3. **Make sure the Vault secrets `project_url` and `anon_key` exist in
   production** (needed by the cron migrations; see
   [MONETIZATION.md §1](MONETIZATION.md)). Use the *new* anon key from step 1.
4. **Add the six missing GitHub Actions secrets** (`SUPABASE_ACCESS_TOKEN`,
   `SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD`, `VERCEL_TOKEN`,
   `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`). See
   [RELEASE.md](RELEASE.md#one-time-setup).
5. **Create a staging Supabase project** (it doubles as the CI test project),
   run `supabase db push` there and confirm all 16 migrations apply. On
   2026-10-16 the chain and the whole integration suite passed on a local
   `supabase start` stack (Postgres 17). That run also found and fixed three
   bugs a fresh project would have hit: sign-up failing, bubble taps failing
   (`tasks.claimed_at` missing), and `cycle_task_status` letting outsiders
   act on unassigned tasks. Staging confirms it on hosted Supabase. Point the
   integration secrets at it too
   ([TESTING_GUIDE.md](../TESTING_GUIDE.md#running-integration-tests-locally)).
6. **Push `main`**, then watch the *Apply database migrations* step. It
   should apply `20260828000001` onwards, which also fixes tags, recurrence
   and timezone in production. Confirm the smoke test passes.

## Phase 1: Turn on Premium on the web (about 1–2 days once Phase 0 is done)

Everything is in [MONETIZATION.md](MONETIZATION.md) §2–§5. Summary:

1. Stripe **test mode**: create the product and price, a Payment Link that
   redirects back to the app, and the Customer Portal.
2. Deploy the `stripe-webhook` edge function to staging with
   `--no-verify-jwt` and set its secrets. Test a purchase, renewal,
   cancellation and a bad signature (should return 400).
3. Set GitHub *variables* `STRIPE_PAYMENT_LINK_URL` and
   `STRIPE_CUSTOMER_PORTAL_URL`. Without them the button says "coming soon".
4. Legal and admin, needed before live mode:
   - Terms of Service with refund and cancellation terms; the privacy policy
     is already updated for Stripe and usage events.
   - Stripe *Public details*: support email, Terms and Privacy URLs.
   - Turn on **Stripe Tax**, or confirm you don't need to collect sales
     tax/VAT yet.
   - Decide which legal entity takes the money (sole proprietor or LLC) and
     use its bank account in Stripe.
5. Repeat in **live mode** for production. Make one real purchase and refund
   it.
6. Add **Vercel Web Analytics** (one script tag in `web/index.html`) so you
   can see visitors and paywall views, not just database writes.

## Monetization strategy (recommendations)

### Model: freemium, one subscription per couple

- Keep **everything needed to share tasks free**: pairing, shared and
  personal tasks, claiming, nudges, recurrence. DuoTask only works if
  *both* people use it, so the free tier is the acquisition channel. Gating
  core sharing would kill the invite loop.
- Charge for **depth and convenience**, bought once for the pair. The code
  already works this way: `get_premium_status()` returns premium if either
  partner subscribes. Market it as "one subscription, both of you get
  Premium".

### Pricing to start with

- **$3.99/month or $29.99/year per couple** (the annual price is about 37%
  off, which is what most people should pick). That's in the range of
  consumer productivity apps, and the per-couple framing makes it feel like
  about $2 each.
- Offer a **14-day free trial** via the Stripe Payment Link setting. It
  lowers the barrier and gives a clean trial-to-paid metric.
- Change price only on evidence: after about 100 paywall views, if
  conversion is very low try the trial or a lower annual price; if it's
  healthy, test $4.99.

### What Premium should include (build in this order)

1. ✅ **Streaks & Stats**: done.
2. **Smart reminders**: due-date reminders and a "your partner is waiting on
   you" push or email. Push is already coded and needs a Firebase project.
   Reminders are the feature most likely to justify paying.
3. **Advanced recurrence**: custom intervals ("every 2 weeks", "1st of the
   month") and task templates or routines ("Sunday reset"). Keep basic
   daily and weekly free.
4. **Shared lists**: groceries and packing lists with check-off. This is a
   frequent couples use case and drives daily opens.
5. **Attachments and notes**: photos of receipts or warranty cards, via
   Supabase Storage (already in the backlog).
6. **Calendar sync**: an iCal feed of shared due dates (read-only first).
7. **Themes and customization**: cheap to build, popular, and good for
   annual-plan upsell.
8. **Family plan (higher tier, later)**: more than two members, at around
   $6.99/month. Needs the multi-partner support from the backlog, which is a
   large schema change, so only build it if users ask for it.

### Growth (paying users come from active pairs)

- **Make inviting effortless.** One-tap share of an invite link that
  pre-fills the pairing code. Measure the share of signups that pair within
  7 days; the SQL is in [MONETIZATION.md](MONETIZATION.md#measuring-usage).
  This is the most important number.
- **Referral reward:** when a new pair completes its first shared task,
  give both inviting partners a free month of Premium.
- **Landing page and SEO:** a marketing page separate from the app, with
  pages like "shared to-do app for couples" and "chore chart for
  roommates". Add an App Store badge once the apps are out.
- **Communities:** couples, newlywed, new-parent and roommate forums. Post
  helpful content, not ads.
- **Lifecycle email:** Resend is already set up. Send day-1 "invite your
  partner", day-3 "how to use recurring chores", and a trial-ending notice.

### Mobile apps (larger revenue, more work)

- Most consumer subscription revenue comes from the app stores. Android
  signing is wired up (needs your keystore, see
  [RELEASE_SIGNING_SETUP.md](RELEASE_SIGNING_SETUP.md)); iOS needs an Apple
  Developer account.
- Store rules generally require **in-app purchase** for digital
  subscriptions sold inside the app. Use **RevenueCat** for Apple and Google
  billing and have its webhook set the same `is_premium` / `premium_until`
  fields the Stripe webhook sets. Then a subscription bought on any
  platform unlocks Premium everywhere. Check the current App Store rules on
  linking out to web checkout before you launch.
- Don't show the Stripe upgrade button in the iOS and Android builds until
  this is decided.

### Metrics to watch (weekly)

| Metric | Why |
|---|---|
| Signups → paired within 7 days | Whether the core loop works; fix this before pricing |
| Pairs completing ≥ 3 shared tasks in week 1 | Activation |
| Week-1 and week-4 retention | Whether there's habit to monetize |
| Paywall views → trial → paid | Pricing and paywall copy |
| Monthly churn of paying pairs | Whether Premium keeps delivering value |

All of these come from `analytics.events`; paywall views are the
`paywall_viewed` event (added 2026-11-13, see
[MONETIZATION.md](MONETIZATION.md#measuring-usage)).

## Bigger growth bets (start only after Phase 0)

*Added 2026-10-16.* Three larger ideas beyond the plan above, in priority
order. None should start before Phase 0 is done: production is probably
broken for tags, recurrence and timezone, and revenue is still $0. Build #1
before any price test, because pricing doesn't matter until pairs form.

### 1. Partner without an install (fixes the pairing bottleneck) ✅ built

**Built 2026-10-16 as "Send to someone" share links; see
[SHARE_LINKS.md](SHARE_LINKS.md).** It ships with the next push of `main`.

Any personal task can go out as a link from the sender's own phone
(WhatsApp, text, email, copy). The recipient answers on a lightweight page
with no account. "Get DuoTask" then signs them up and pairs the two of you
automatically.

It differs from the idea as first written in two ways:
- **No Twilio.** The sender's phone sends the message, so there are no SMS
  costs or carrier registration, and the message comes from someone the
  recipient trusts.
- **No edge function.** Token-checked RPCs serve the page.

Measure the funnel query in SHARE_LINKS.md, plus signups paired within 7
days.

### 2. Fairness and invisible work as the Premium story

Couples rarely fight about tasks; they fight about fairness and the mental
load of remembering everything. Make that the reason to pay:

- **Who owns what:** each partner owns a whole area (kids' school, car,
  bills), including noticing and planning, not just doing.
- **Weekly balance report:** who did what, the effort involved, and who
  carried the planning. Extends `lib/utils/pair_stats.dart`.
- **10-minute weekly check-in** that rebalances the coming week.

Positioning: *"the app that ends the 'I do everything' fight."* It also
opens a B2B2C channel: couples therapists and premarital counselors who
recommend it to clients, later with a simple counselor view. Use our own
wording; "Fair Play" is someone else's brand.

**Wild card that fits here:** an AI brain dump. Type, say or photograph
something messy (a school flyer, a landlord letter), and Claude turns it
into tasks, splits them by who usually does what, and suggests due dates.
Treat it as a Premium feature, not the headline.

### 3. Earn from tasks, not only subscriptions

Household tasks show buying intent: groceries, "fix the faucet", "book a
sitter", moving. Most free users will never subscribe; this earns from them
anyway.

- **"Outsource it"** on matching tasks, linking to Instacart, TaskRabbit,
  Thumbtack, Care.com and similar through their affiliate or referral
  programs. Check each program's terms before launch.
- **Life-event packs:** moving, new baby and wedding planning task sets,
  $4.99 each or included in Premium, with relevant affiliate links (movers,
  insurance, registries).
- **Gifting:** sell packs and a year of Premium as wedding and baby-shower
  gifts. That brings in new couples at their most motivated moment.

Measure clicks and affiliate revenue per active pair, and gift purchases
that lead to a new pair.

## Phase 2 onwards: suggested sequence

| When | Work |
|---|---|
| Week 1 | Phase 0 (security, migration reconciliation, CI green) |
| Week 2 | Phase 1 (Premium live on web), Web Analytics, invite-link polish |
| Weeks 3–4 | Watch the share-link funnel (bet #1, built); reminders (Firebase push and email) as Premium; referral reward; landing page |
| Month 2 | Fairness features and balance report as the Premium story (bet #2); advanced recurrence and templates; lifecycle emails |
| Month 2–3 | "Outsource it" affiliate links, life-event packs and gifting (bet #3); shared lists |
| Month 2–3 | Android release (Play Store) with RevenueCat; then iOS |
| Month 3+ | Review metrics: price test, attachments, calendar sync; family plan only if users ask |

## Engineering backlog that supports this

- Stop committing `build/web` once one CI deploy is green.
- Run the 5 integration tests against the staging project in CI.
- Explicit timezone picker in Settings (the device offset is captured
  silently today, and half-hour offsets fall back to UTC).
- Update the Supabase CLI (installed 2.39.2, current 2.121.0) and set
  `[db] major_version = 17` in `supabase/config.toml` to match production.
- Offline mode (queue changes, sync later), from
  [UNIMPLEMENTED_FEATURES.md](../UNIMPLEMENTED_FEATURES.md).

## Picking this up on the Mac mini

```bash
cd DuoTask
git fetch origin
git checkout main
git merge --ff-only origin/macmini-sync
```

That brings local `main` up to date **without** pushing `main` to GitHub,
so nothing deploys. Start at Phase 0, step 1. Two other things to know:

- `supabase/migrations/` changes are the riskiest part. Always run
  `supabase migration list` before any push to `main`.
- The schema dump of production from 2026-10-15 wasn't saved in the repo.
  Regenerate it with `supabase db dump --linked -s public -f /tmp/prod.sql`
  (needs Docker running).
