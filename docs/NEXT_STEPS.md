# EvenHalf: monetization and growth plan

*Strategy only. What to do **next** lives in [NEXT_ACTIONS.md](NEXT_ACTIONS.md);
this page is the longer plan that follows it. Last reviewed 2026-11-17.*

## Phase 1: Turn on Premium on the web (after everything in [NEXT_ACTIONS.md](NEXT_ACTIONS.md) is done)

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

## Competition and positioning (checked 2026-11-17)

The "shared chores for couples" category is crowded and mostly iOS-only:
another app with our old name (iPhone, with the matching `.app` domain; that's why we
renamed, see [NEXT_ACTIONS.md §0](NEXT_ACTIONS.md#0-rename-to-evenhalf-blocks-marketing-not-the-merge)),
*Chores Together* (points and rewards), *Chore Wars* (XP),
*Pairwork* (hourly value of housework), *Chores* (recurring tasks),
*DuoMode* (Android habits), and Cupla (couples calendar). Most of them compete
on gamification.

Lead with what they don't do:

1. **Your partner doesn't need to install anything.** Send a task over
   WhatsApp or text and they answer from a link. Nobody else has this, and it
   removes the biggest problem with any two-person app: getting the second
   person to sign up.
2. **Works on any phone, today.** Web and PWA, so mixed iPhone/Android
   couples work from day one.
3. **Fairness and mental load, not points** (bet #2 below). Gamified apps
   wear off; "the app that ends the 'I do everything' fight" doesn't.

Every landing page, store listing and post should open with #1.

**Brand line:** *EvenHalf: your better half, evened out.* Short form for
store listings: "Shared to-do list for couples. No app needed for your
partner."

## Monetization strategy (recommendations)

### Model: freemium, one subscription per couple

- Keep **everything needed to share tasks free**: pairing, shared and
  personal tasks, claiming, nudges, recurrence. EvenHalf only works if
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

## Bigger growth bets (start only after NEXT_ACTIONS.md is done)

*Added 2026-10-16.* Three larger ideas beyond the plan above, in priority
order. None should start before NEXT_ACTIONS.md is done: production is probably
broken for tags, recurrence and timezone, and revenue is still $0. Build #1
before any price test, because pricing doesn't matter until pairs form.

### 1. Partner without an install (fixes the pairing bottleneck) ✅ built

**Built 2026-10-16 as "Send to someone" share links; see
[SHARE_LINKS.md](SHARE_LINKS.md).** It ships with the next push of `main`.

Any personal task can go out as a link from the sender's own phone
(WhatsApp, text, email, copy). The recipient answers on a lightweight page
with no account. "Get EvenHalf" then signs them up and pairs the two of you
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
| Week 1 | [NEXT_ACTIONS.md](NEXT_ACTIONS.md) (security, staging, merge) |
| Week 2 | Phase 1 (Premium live on web), Web Analytics, invite-link polish |
| Weeks 3–4 | Watch the share-link funnel (bet #1, built); reminders (Firebase push and email) as Premium; referral reward; landing page |
| Month 2 | Fairness features and balance report as the Premium story (bet #2); advanced recurrence and templates; lifecycle emails |
| Month 2–3 | "Outsource it" affiliate links, life-event packs and gifting (bet #3); shared lists |
| Month 2–3 | Android release (Play Store) with RevenueCat; then iOS |
| Month 3+ | Review metrics: price test, attachments, calendar sync; family plan only if users ask |

## Engineering backlog that supports this

- Stop committing `build/web` once one CI deploy is green.
- Run the 5 integration tests against the staging project in CI.
- Detect the device's real IANA timezone on first load (needs a plugin such
  as `flutter_timezone`). The Settings picker exists now, but new accounts
  still start on a whole-hour `Etc/GMT` guess, and half-hour offsets (India,
  Nepal) start on UTC until the user picks a zone.
- Update the Supabase CLI (installed 2.39.2, current 2.121.0) and set
  `[db] major_version = 17` in `supabase/config.toml` to match production.
- Offline mode (queue changes, sync later), from
  [UNIMPLEMENTED_FEATURES.md](../UNIMPLEMENTED_FEATURES.md).
