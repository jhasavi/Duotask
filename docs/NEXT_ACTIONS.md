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

`git pull`, `flutter pub get`, `supabase login`,
`supabase link --project-ref xqhlnuvpogiolzkucupt`, `vercel login`,
`gh auth login`. Copy `.env` over securely (AirDrop or a password manager,
never email or chat). `.env` currently lists `SUPABASE_ANON_KEY` twice; keep
one.

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

- Mail for `support@duotask.app` and `privacy@duotask.app`.
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
