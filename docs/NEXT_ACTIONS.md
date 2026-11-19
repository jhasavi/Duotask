# Next actions before release

*Written 2026-11-17 on the Mac mini. This is the **only** to-do list; the other
docs are reference. Branch: `feat/launch-readiness` (PR 11). The code is done:
`flutter analyze` clean, 193 tests pass, CI green.*

**Rule: do not merge PR 11 until steps 1 to 5 are done.** Merging to `main`
runs `supabase db push` against production.

## Done already

- Resend: leaked key deleted, new key created, set in `.env` **and** as the
  Supabase secret `RESEND_API_KEY` (2026-11-17).
- Discord: bot token reset. Nothing runs the bot.
- Vercel: nothing to rotate. The tokens on the account are Claude/CLI/website
  sign-ins; the leaked OIDC token was short-lived and has expired.
- Supabase production migration history: baseline plus `20250625000001`–`05`
  are recorded. The 17 newer migrations are unapplied on purpose.
- New Supabase API keys (publishable and secret) created and saved in `.env`.

## Moving to the MacBook

Done 2026-11-17: the MacBook is on `feat/launch-readiness` and `.env` was
copied from the Mac mini over SSH. The duplicate `SUPABASE_ANON_KEY` line
(both copies were the same) was dropped, and the MacBook-only
`VERCEL_URL` / `WEB_REDIRECT_URL` were kept. `flutter analyze` is clean.
Folder is now `~/EvenHalf` on both machines and the GitHub repo is
`jhasavi/EvenHalf` (see §0). Still per machine if needed: `supabase login`,
`supabase link --project-ref xqhlnuvpogiolzkucupt`, `vercel login`.

## 0. Rename to EvenHalf (blocks marketing, not the merge)

**Why:** on 2026-11-17 we found another "DuoTask" in the same niche, an iPhone
shared to-do app for couples
([App Store id6752819525](https://apps.apple.com/us/app/duotask/id6752819525))
that owns `duotask.app`. Our legal pages were sending users' mail there. We
renamed to **EvenHalf** (a pun on "better half": share the load evenly).
On 2026-11-17 `evenhalf.com` and `evenhalf.app` were both unregistered, and
no App Store app used the name.

**Done in code (2026-11-17):** every user-facing string, the web pages,
emails, the PWA manifest and the Dart package (`package:evenhalf`). The
Android/iOS bundle id is now `com.namasteneedham.evenhalf` (safe, nothing is
published). Legal contacts are `support@` and `privacy@evenhalf.app`.
Public pages `/privacy/` and `/terms/` are generated from `assets/docs/*.md`
by `scripts/build_legal_pages.py` and linked from the landing page footer.

**Kept on purpose (they're tied to outside consoles):** the live host
`duotask.namasteneedham.com`, the Supabase OAuth URL scheme
`io.supabase.duotask`, the Supabase project ref, Resend key names, and the
placeholder Firebase ids. Old migrations and CHANGELOG entries still say
DuoTask; that's history.

**Also renamed (2026-11-17):** GitHub repo `jhasavi/EvenHalf` (old URL
redirects), folder `~/EvenHalf` on the MacBook (with a `~/DuoTask` symlink) and
on the Mac mini, the entries in `sync-projects.sh` / `msync.sh` (installed
copies on both machines; the copies in `~/nb/scripts/maintenance` are edited
but not committed). The namasteneedham.com pages moved to `/evenhalf/*` with
redirects from `/duotask/*`: [jhasavi/nneedham#8](https://github.com/jhasavi/nneedham/pull/8),
not merged yet.

**Two sets of legal pages to reconcile:** the app's own Terms and Privacy
(`assets/docs/*.md`, now also at `/terms/` and `/privacy/`, contact
`support@evenhalf.app`) and the shorter, more current ones on
namasteneedham.com/evenhalf (contact `info@namasteneedham.com`). Pick one as
the source of truth before Stripe live mode and store listings; the app's
version has the refund terms Stripe needs.

**Your steps, in order:**

1. **Buy `evenhalf.com` and `evenhalf.app` today** (Cloudflare Registrar or
   Namecheap, about $10 + $15/year). Until then someone else can take them.
   Then do a free USPTO search for "EvenHalf" (classes 9 and 42):
   https://tmsearch.uspto.gov
2. **Email:** turn on Cloudflare Email Routing (free) for `evenhalf.app` and
   forward `support@` and `privacy@` to your inbox. The Terms and Privacy
   Policy already list them.
3. **Point the domain at Vercel:** add `evenhalf.app` (primary) and
   `evenhalf.com` (redirect) to the Vercel project. Keep
   `duotask.namasteneedham.com` as a redirect so old share links work.
4. **Switch the app URL in one go** (ask Claude, it's a find-and-replace):
   `_defaultPublicAppUrl` in `lib/config/app_config.dart`, `APP_URL` default
   in both email functions, the canonical/OG tags in `web/index.html` and
   `web/welcome/index.html`, `web/sitemap.xml`, `web/robots.txt`.
5. **Consoles that hold the old URL or name:**
   - Supabase → Authentication → URL Configuration: Site URL and redirect
     URLs for the new domain; Email Templates: replace "DuoTask".
   - Google Cloud → OAuth client: add the new domain as an authorized
     JavaScript origin; rename the consent screen to EvenHalf.
   - Resend: verify `evenhalf.app` as a sending domain and set the edge
     function secret `EMAIL_FROM` to `EvenHalf <hello@evenhalf.app>`.
   - Stripe (when set up): business name EvenHalf, Terms
     `https://evenhalf.app/terms/`, Privacy `https://evenhalf.app/privacy/`.
   - Vercel and GitHub project names (cosmetic).
6. Claim `@evenhalf` (or `@evenhalfapp`) on X, Instagram and TikTok before
   posting anything.

## 1. Close the Supabase key leak (blocking)

The leaked `service_role` key still works. Creating new API keys did **not**
revoke it. There is no "generate new JWT secret" button in the dashboard now,
so the way to kill it is to move everything to the new keys and then disable
the legacy ones. Order matters, and nothing is disabled until the last step:

1. **Check how the code uses keys.** The web app reads `SUPABASE_ANON_KEY` via
   `--dart-define` (`scripts/build_web.sh`, `lib/config/app_config.dart`).
   Confirm the installed `supabase_flutter` version accepts an `sb_publishable_`
   key before switching.
2. **Database cron jobs and push triggers** send `Bearer <anon_key>` from the
   Vault secret `anon_key` to the edge functions. The new keys are not JWTs, so
   decide per function: set `verify_jwt = false` in `supabase/config.toml` and
   have the function check a shared secret itself, or keep the legacy anon key
   until it is retired. Test on staging first.
3. **Edge functions** read `SUPABASE_SERVICE_ROLE_KEY`. Replace with the new
   secret key (set a function secret, change the code to read it), redeploy
   `daily-email-digest`, `send-nudge-push`, `lifecycle-emails`,
   `stripe-webhook`.
4. Update the GitHub secret `SUPABASE_ANON_KEY` and the Vault `anon_key` to the
   publishable key. Rebuild and redeploy the web app.
5. Verify: sign in on the live site, send a nudge, invoke
   `supabase functions invoke daily-email-digest`, run
   `scripts/smoke_test.sh https://duotask.namasteneedham.com`.
6. **Only then** Dashboard → API Keys → **Disable legacy API keys**. Re-test
   the same things. Proof it worked: a request using the old `service_role`
   key returns 401.

Also: the legacy JWT secret itself was shown on screen in a Claude session on
2026-11-17. Step 6 makes it moot, but do not skip step 6.

## 2. Add the six GitHub Actions secrets

`SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF` (`xqhlnuvpogiolzkucupt`),
`SUPABASE_DB_PASSWORD`, `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`.
Create a `VERCEL_TOKEN` scoped to the DuoTask project. Details:
[RELEASE.md](RELEASE.md#one-time-setup). Currently present: `SUPABASE_URL`,
`SUPABASE_ANON_KEY` and the three `GOOGLE_*` ids.

## 3. Staging

The Supabase org has 2 projects already; a third may need a paid plan. Either:
- create a staging project and run `supabase db push` against it, or
- start Docker, run `supabase start`, and run the integration suite
  (see [TESTING_GUIDE.md](../TESTING_GUIDE.md)).

Confirm all 23 local migrations apply cleanly, then run
`flutter test test/integration` against it. The November migrations
(account deletion, invite links, lifecycle emails) have only run on the CI test
project, not on a hosted staging copy.

## 4. Check production before the merge

- In the SQL editor: `select jobname, schedule from cron.job;` The daily digest
  job exists if `20250625000005` really ran; schedule `0 * * * *` means
  `20260828000002` did too.
- Confirm the Vault secrets `project_url` and `anon_key` exist.
- `supabase migration list` should still show 17 unapplied.
- On the live site, create a task with a tag. It probably errors today because
  `tasks.tags` doesn't exist in production yet. That's what the merge fixes.

## 5. Merge and verify

Merge PR 11. Watch *Apply database migrations*, then run the smoke test. Then
deploy and schedule `lifecycle-emails`
([LIFECYCLE_EMAILS.md](LIFECYCLE_EMAILS.md)) and send a test digest to confirm
the new Resend key works.

## 6. Owner and legal items (no code)

- Mail for `support@evenhalf.app` and `privacy@evenhalf.app` (see §0 step 2).
- Legal review of the Terms: Massachusetts jurisdiction, 14-day refund window,
  arbitration clause.
- Enable Vercel Web Analytics in the Vercel dashboard.
- Resend hygiene: `duotask-prod` and `duotask-dev` have Full access and no
  activity. Delete `duotask-dev`; give prod Sending access only.

## 7. Later (not blocking)

- Premium on Stripe: test mode, then live
  ([MONETIZATION.md](MONETIZATION.md), [NEXT_STEPS.md](NEXT_STEPS.md)).
- Push notifications need a real Firebase project
  ([PUSH_NOTIFICATIONS_SETUP.md](PUSH_NOTIFICATIONS_SETUP.md)).
- Android/iOS store releases: only after about 100 active pairs
  ([LAUNCH_PLAN.md](LAUNCH_PLAN.md)).
- Optional: delete the 18 "Claude via Sign in with Vercel" tokens at
  vercel.com/account/tokens (Claude then needs to reconnect).
