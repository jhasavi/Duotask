# Moving to the new Supabase keys (runbook)

Tested locally 2026-11-19 against `supabase start` (Postgres 17, all 18
migrations): `flutter test --tags integration` passed (38 tests); the three
cron-called functions return 401 without the `FUNCTION_AUTH_SECRET` Bearer and
200 with it; `stripe-webhook` still rejects unsigned calls with 400.

Script: `scripts/prod_key_migration.sh <stage>` (production stages need
`CONFIRM=yes`; no secret is printed). Each stage needs Sanjeev's yes.

| # | Stage | Command / action | Who |
|---|-------|------------------|-----|
| 0 | Read-only check | `scripts/prod_key_migration.sh preflight` | Claude |
| 1 | Function secrets | `CONFIRM=yes scripts/prod_key_migration.sh secrets` | Claude |
| 2 | Deploy the 4 functions | `CONFIRM=yes scripts/prod_key_migration.sh deploy` | Claude |
| 3 | Vault `anon_key` := function secret | `CONFIRM=yes scripts/prod_key_migration.sh vault`, paste in SQL Editor | Sanjeev pastes |
| 4 | GitHub secrets | add the six from NEXT_ACTIONS §2; set `SUPABASE_ANON_KEY` to the **publishable** key (`SUPABASE_PUBLISHABLE_KEY` in `.env`) | Sanjeev |
| 5 | Merge PR 11 (runs `db push`, 18 migrations) | explicit yes first | Sanjeev |
| 6 | Build and deploy web | `scripts/build_web.sh`, deploy `build/web` to Vercel project `duotask`, `scripts/smoke_test.sh https://evenhalf.namasteneedham.com` | Claude |
| 7 | Verify | sign in on the live site, send a nudge, `scripts/prod_key_migration.sh verify` | both |
| 8 | Disable legacy keys (last, separate) | Dashboard > API Keys > Disable legacy; then `LEGACY_SERVICE_ROLE_KEY=... scripts/prod_key_migration.sh legacy-check` must print 401 | Sanjeev + Claude |

Before step 3 the old Vault value still works only until step 8; cron needs
migrations from step 5 to exist in production (the cron jobs are created by
them, and they require the Vault secrets `project_url` and `anon_key`).

Also delete the stray custom function secret `SERVICE_ROLE_KEY` (likely the
legacy key) before step 8, and audit the five functions that exist only in
production (`auth-email-branding`, `pairing-email`, `daily-summary`,
`send-push`, `send-fcm`) in the dashboard for use of legacy keys.

## Supabase console values for https://evenhalf.namasteneedham.com

- Authentication > URL Configuration > Site URL: `https://evenhalf.namasteneedham.com`
- Redirect URLs: `https://evenhalf.namasteneedham.com/**` (keep the old
  `https://duotask.namasteneedham.com/**` and the OAuth URL scheme until the
  old host is retired)
- Google Cloud OAuth client: authorized JavaScript origin
  `https://evenhalf.namasteneedham.com`; consent screen name EvenHalf
- Email templates: replace the old app name with EvenHalf
- Function secret `APP_URL` = `https://evenhalf.namasteneedham.com`
- GitHub secret `WEB_REDIRECT_URL` = `https://evenhalf.namasteneedham.com`
