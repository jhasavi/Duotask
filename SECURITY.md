# Security

## Credential handling

**No secret may ever be committed to this repository.** This is enforced, not
just requested — see "Automated guards" below.

### What is and is not a secret

| Value | Secret? | Why |
|---|---|---|
| `SUPABASE_ANON_KEY` | No | Client-side credential by design; safety comes from row-level security, not secrecy. Safe to ship in the web bundle. |
| `SUPABASE_SERVICE_ROLE_KEY` | **Yes** | Bypasses all row-level security. Server/CI only. Never in app code, never in a test file, never in a migration. |
| `RESEND_API_KEY` | **Yes** | Allows sending mail as our domain. Edge-function environment only. |
| `DISCORD_TOKEN` | **Yes** | Full control of the bot account. |
| `VERCEL_TOKEN`, `VERCEL_OIDC_TOKEN` | **Yes** | Deploy access. CI secrets only. |
| Google OAuth client IDs | No | Public by design. |

### Where configuration lives

- **Local development** — a `.env` file, git-ignored. Copy `.env.example`.
- **Web builds** — injected with `--dart-define` by `scripts/build_web.sh`.
  Nothing is read from a bundled `.env` asset in a release build.
- **CI/CD** — GitHub repository secrets. See the header comments in
  `.github/workflows/deploy.yml` and `integration.yml` for the required names.
- **Database (cron jobs)** — Supabase Vault. `migrations/setup_email_cron.sql`
  reads credentials at run time rather than embedding them.

## Automated guards

| Guard | Runs | Catches |
|---|---|---|
| `scripts/verify_bundle.sh` | Every build, and in CI | Env files or secret-shaped strings inside `build/web`. |
| `secret-scan` job (`.github/workflows/ci.yml`) | Every push and PR | Tracked env files; Resend keys, `service_role` JWTs, Discord tokens in any tracked file. |
| `scripts/smoke_test.sh` | After every deploy | A publicly readable `.env` or secrets in the served bundle. |

If any of these fail, treat it as a release blocker. Do not add exclusions to
make them pass.

## Past incident

A `.env` file was committed inside `build/web/assets/`. Because Vercel served
the committed `build/web` directory directly (`buildCommand: null`), the file
was readable by anyone at `https://<domain>/assets/.env`. It exposed a live
Resend API key and a Discord bot token. A Supabase `service_role` JWT was
separately hardcoded in an integration test on a pushed branch.

All of these have been removed from the working tree, **but they remain in git
history**. Rotation is the only real remediation:

- [ ] Rotate `RESEND_API_KEY` (Resend dashboard → API Keys)
- [ ] Reset the Discord bot token (Discord Developer Portal → Bot → Reset Token)
- [ ] Rotate the Supabase `service_role` key
- [ ] Rotate the Vercel token
- [ ] Review Resend send logs and Supabase auth logs for unauthorized use

**Step-by-step instructions: [docs/CREDENTIAL_ROTATION.md](docs/CREDENTIAL_ROTATION.md).**

Optionally, purge the blobs from history with `git filter-repo` and force-push.
Rotation matters more; history rewriting without rotation fixes nothing,
because clones and forks may already exist.

## Reporting

Report suspected vulnerabilities privately to the repository owner rather than
opening a public issue.
