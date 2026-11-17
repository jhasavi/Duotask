# Handoff: continuing on the MacBook (2026-11-17)

State of `feat/launch-readiness` (PR 11): code is done. `flutter analyze`
clean, 193 tests pass, the formatting CI failure is fixed. **Do not merge
yet**: merging runs `supabase db push` against production.

## Verified on 2026-11-17

| Item | Finding |
|---|---|
| Resend | The leaked key (`re_jR6ucccW_…`) is **gone**: the account now lists 4 keys, none matching. `duotask-prod` and `duotask-dev` are Full access with no activity; consider deleting `duotask-dev` and narrowing prod to Sending access. |
| Supabase production migration history | Already repaired: remote records baseline + `20250625000001`–`05`. The other 16 local migrations are unapplied (expected until the merge). |
| Supabase JWT | Dashboard → JWT Keys still shows the **legacy JWT secret in use**. Nothing proves the leaked `service_role` key was rotated. Treat as **not rotated**. |
| Discord | App `DuoTask` (id 1440406561393737892) still exists. The token can't be inspected, only reset. **Not reset yet.** |
| Vercel tokens | 20 tokens: 18 are "Claude via Sign in with Vercel" (OAuth sessions from connecting Claude), 1 is Vercel CLI, 1 is a website login. None is the leaked `VERCEL_OIDC_TOKEN` (short-lived, expired). Nothing to rotate. Optional: delete the 18 Claude ones, then reconnect Claude to Vercel. |
| GitHub Actions secrets | Only `SUPABASE_URL`, `SUPABASE_ANON_KEY` and the three `GOOGLE_*` ids exist. The six deploy secrets are still missing. |
| Docker | Not running here, so no local `supabase start` this session. |

## Still to do (in order)

1. Reset the Discord bot token (Developer Portal → DuoTask → Bot → Reset
   Token). Nothing runs the bot, so nothing breaks. Or delete the application.
2. Rotate the Supabase JWT secret, then update `SUPABASE_ANON_KEY` in GitHub
   secrets, the Vault `anon_key` secret and your local `.env`, redeploy edge
   functions, rebuild the web app. Steps: `docs/CREDENTIAL_ROTATION.md` §3.
3. Add the six GitHub Actions secrets (`SUPABASE_ACCESS_TOKEN`,
   `SUPABASE_PROJECT_REF=xqhlnuvpogiolzkucupt`, `SUPABASE_DB_PASSWORD`,
   `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`).
4. Create a staging Supabase project (the org has 2 projects already; a third
   may need a paid plan) and run `supabase db push` there.
   Or run `supabase start` locally (needs Docker) and run the integration
   suite. It passed on 2026-10-16 but has not been run for the Nov migrations
   against a hosted project.
5. Merge PR 11, watch *Apply database migrations*, run
   `scripts/smoke_test.sh https://duotask.namasteneedham.com`.
6. Deploy and schedule `lifecycle-emails`; set mail for `support@` and
   `privacy@duotask.app`; get the Terms reviewed.

## Moving machines

Everything is in git on `feat/launch-readiness`. Not in git: `.env`
(gitignored), the Supabase CLI login and link, the Vercel CLI login, and
`gh auth`. On the MacBook: `git pull`, `flutter pub get`,
`supabase login && supabase link --project-ref xqhlnuvpogiolzkucupt`,
`vercel login`, `gh auth login`, and copy `.env` over securely (not by
email or chat).
