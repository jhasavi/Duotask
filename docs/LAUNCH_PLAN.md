# DuoTask launch plan: social posts, app stores, and making money

*Written 2026-10-23. Complements [NEXT_STEPS.md](NEXT_STEPS.md); it doesn't replace it.*

## Verdict

1. **Stay web-only for now.** Don't pay for Apple or Google yet. The web app
   is installable (PWA), works on phones, and costs nothing per sale.
2. **Don't promote it until Phase 0 of NEXT_STEPS.md is done.** Production
   probably still lacks the tags/recurrence/timezone/share-link migrations,
   and the leaked keys are not rotated. Advertising a broken product wastes
   the one first impression you get.
3. **Then post.** Posting is free. Paid ads are not worth it until you know
   what a signup is worth.
4. **Go to the stores only on evidence**: about 100 active pairs, and people
   asking for an app. Android first ($25 once), iOS later ($99/year).

## Test results (2026-10-23)

| Check | Result |
|---|---|
| `flutter analyze` | 0 issues |
| Hermetic tests | 148 pass |
| Integration tests, local Supabase with the full migration chain | 12 pass (sign-up race, pairing, share links) |
| Live site smoke test (`scripts/smoke_test.sh`) | Pass; no secrets in the bundle |
| Browser: sign-up, add task, tap-to-cycle on a local build | Works |
| Browser: share page at phone width, "I'll do it" | Works; the DB shows `accepted` |
| Android / iOS builds | **Not tested here**: Android licenses not accepted, Xcode not installed |

Bugs found and fixed in this pass:

- **Task parser lost information when keywords combined.** "Pick up dry
  cleaning tomorrow @6pm urgent" became a task titled "Pick up dry cleaning
  @6pm urgent" due at 9am. "Read urgently" became "Read ly". Fixed in
  `parseNaturalInput`, with three new tests.
- **No link previews.** Links posted on X or Facebook would show a bare URL.
  Added Open Graph and Twitter card tags to `web/index.html`. The image is the
  app icon; a 1200x630 banner would look better.

Still open:

- Terms of Service has no refund or cancellation terms (needed for Stripe live
  mode).
- ~~No Vercel Web Analytics, so you can't see visitors or paywall views.~~
  Both added: Vercel Web Analytics and a `paywall_viewed` event.
- Tapping a bubble twice quickly goes Claimed → Completed with no
  confirmation; the undo snackbar is the only safety net.

## Social posts (free)

Do these yourself; they come from your accounts. The product's hook is *fairness
between two people*, not "task app". Lead with the problem.

**X, launch post**
> "Who's doing that?" is the most-asked question in every household.
> I built DuoTask: a shared to-do for two people. Tasks are bubbles, you claim
> them, nudge each other, and it confetti-bombs you when something's done.
> Free: https://duotask.namasteneedham.com

**X, the invite hook** (the strongest feature: no install needed to respond)
> You can send a task to your partner over WhatsApp and they can say "I'll do
> it" from a link. No app, no account. That's DuoTask. https://duotask.namasteneedham.com

**Facebook (personal or a page)**
> I made a small app for couples and roommates: one shared task list where you
> claim chores instead of nagging. Free, works in your browser, and you can
> send a task to someone by WhatsApp or text so they don't even need to sign
> up. I'd love feedback from anyone who shares a home. [link]

Tips: attach a 15-second screen recording of the bubble board plus the share
page on a phone. Post in couples, newlywed, new-parent and roommate groups only
where self-promotion is allowed; read each group's rules first. Reply to every
comment in the first hour.

## Web, Android, iOS: what each costs

| | Cost | Payment cut | Effort | Verdict |
|---|---|---|---|---|
| Web (now) | Hosting only | Stripe about 2.9% + 30c | Done | **Do this first** |
| Android (Play Store) | $25 once | About 15% on subscriptions | Keystore ([RELEASE_SIGNING_SETUP.md](RELEASE_SIGNING_SETUP.md)), Firebase, Play listing, testing | After about 100 active pairs |
| iOS (App Store) | $99/year, needs a full Xcode install | 15% under Apple's Small Business Program, else 30% | Everything Android needs plus review rejections | Last; only if iPhone users ask |

Fees are from third-party summaries (for example
[RevenueCat](https://www.revenuecat.com/blog/engineering/small-business-program.md),
[SplitMetrics](https://splitmetrics.com/blog/google-play-apple-app-store-fees/)).
Check Apple's and Google's own pages before you pay. Google's fee structure
changed in 2026 and sources disagree.

Why web-first is right here:

- Every signup comes from an invite link. Links open in a browser, and a
  browser needs no install.
- Stripe keeps about 97%; the stores keep 15–30%.
- Store apps need in-app purchase for subscriptions (RevenueCat is the usual
  route) and review for every update. That is weeks of work before the first
  dollar.
- Add the app to the home screen as a PWA in the meantime. Test "Add to Home
  Screen" on an iPhone and an Android phone and put the instructions on the
  landing page.

When you do go to stores, the code is closer than it looks: the app ID
(`com.namasteneedham.duotask`), icons and Android signing are wired. Missing:
the keystore, a real Firebase project, an Xcode install, and RevenueCat.

## How to make money

Realistic expectation: this is a small niche product. At $29.99/year per
couple, 100 paying couples is about $3,000/year before fees. It's worth doing
because it costs almost nothing to run, not because it will replace income.
Don't spend on ads until organic signups convert.

1. **Fix the base first** (NEXT_STEPS Phase 0, about a day).
2. **Turn on Premium via Stripe test mode, then live** (NEXT_STEPS Phase 1).
   Everything is built: webhook, paywall, Streaks & Stats. Add refund terms to
   the Terms of Service first.
3. **Price**: $3.99/month or $29.99/year per couple, 14-day trial. Both
   partners get Premium from one subscription.
4. **Measure before changing anything**: signups, paired within 7 days, paywall
   views, trials, paid. The SQL is in [MONETIZATION.md](MONETIZATION.md).
5. **Add reasons to pay**: smart reminders, then shared grocery lists, then
   the weekly fairness report.
6. **Distribution that costs nothing**: the share-link flow is the growth loop.
   Watch the funnel query in [SHARE_LINKS.md](SHARE_LINKS.md). A landing page
   for "shared to-do app for couples" and "chore chart for roommates" is the
   next best investment.
7. **Selling the whole product instead**: small apps like this typically sell
   for a low multiple of annual revenue, and with no revenue there is nothing
   to value. Get to recurring revenue first.

## Before you post anything

- [ ] Phase 0: rotate credentials, reconcile production migrations, deploy
- [ ] Create a test account on production and run through sign-up, pairing,
      adding a tagged task and sending a task by link
- [ ] Add Vercel Web Analytics
- [ ] Refund/cancellation terms in `assets/docs/terms_of_service.md`
- [ ] A support email address on the site
