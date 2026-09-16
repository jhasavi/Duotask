# DuoTask — Project Status

*Last updated: September 16, 2026*

## Current version: 1.2.0

| | |
|---|---|
| Branch | `main`, synced with `origin/main` |
| Hermetic tests | 80 passing |
| Integration tests | 5 written, **not yet executed** (need a test project) |
| Static analysis | **0 issues** (was 169) |
| Merge gates | PR required; `Analyze, test, build` + `Secret scan` must pass |
| Production deploy | Current build, **leak closed** (verified 2026-09-16) |

---

## 🔴 Blocking before release

These are the only things standing between the current code and a shippable
product. Everything else on this page is done.

### 1. Rotate the exposed credentials — *owner action, cannot be automated*

A Resend API key and a Discord bot token were served publicly at
`https://<domain>/assets/.env`, and a Supabase `service_role` key was
hardcoded in a pushed test file. They are out of the working tree but remain
in git history.

- [ ] Rotate `RESEND_API_KEY`
- [ ] Reset the Discord bot token
- [ ] Rotate the Supabase `service_role` key
- [ ] Rotate the Vercel token
- [ ] Check Resend and Supabase auth logs for unauthorized use

Step-by-step: **[docs/CREDENTIAL_ROTATION.md](docs/CREDENTIAL_ROTATION.md)**.
Background: [SECURITY.md](SECURITY.md).

### 2. ~~Redeploy~~ — *done, verified 2026-09-16*

Production now serves the current build. Verified against
`https://duotask.namasteneedham.com`:

- `main.dart.js` is **byte-identical** to the local `build/web` output
  (sha256 `bc853891a8…`), so the sign-up race fix and the v1.3 work are live
- `/assets/.env` no longer exists — the path returns the SPA shell via the
  catch-all rewrite, with no env-style keys in the body
- No Resend key or `service_role` JWT anywhere in the served bundle
- `scripts/smoke_test.sh https://duotask.namasteneedham.com` **passes**

The active exposure is closed. Rotation (item 1) is still required: those
credentials were public for roughly two and a half months and remain in git
history.

### 3. Configure CI secrets — *unblocks everything automated*

`deploy.yml` and `integration.yml` are written but inert until their secrets
exist. See [docs/RELEASE.md](docs/RELEASE.md#one-time-setup).

`SUPABASE_URL` and `SUPABASE_ANON_KEY` are already set. The deploy preflight
names the rest on every failed run — as of 2026-09-16, six remain:

- [ ] `SUPABASE_ACCESS_TOKEN`
- [ ] `SUPABASE_PROJECT_REF`
- [ ] `SUPABASE_DB_PASSWORD`
- [ ] `VERCEL_TOKEN`
- [ ] `VERCEL_ORG_ID`
- [ ] `VERCEL_PROJECT_ID`
- [ ] Create a dedicated Supabase **test** project and add its three secrets
- [ ] Confirm one green CI deploy, then stop committing `build/web`

`WEB_REDIRECT_URL` and `GOOGLE_WEB_CLIENT_ID` are optional; the preflight
warns but does not fail when they are unset.

---

## ✅ Done

### Security
- Committed env files untracked and removed; `.gitignore` hardened
- `service_role` key removed from the integration test → environment-injected
- Cron migrations read credentials from Supabase Vault
- Web builds inject config via `--dart-define`; no `.env` ships in the bundle
- Password change now requires and verifies the current password
- Bundle scanner, tracked-file secret scan, and post-deploy smoke test

### Release automation
- `ci.yml` — analyze (fatal on warnings), hermetic tests, build, secret scan
- `integration.yml` — live-backend tests against a test project
- `deploy.yml` — migrations → build → verify → deploy → smoke test
- `scripts/build_web.sh` — the only supported way to build for release
- Duplicate `flutter-ci.yml` workflow removed

### Testing
- Hermetic and live-backend suites separated; `flutter test` no longer touches
  production
- Pairing flow automated (4 tests) — replaces the manual two-user checklist
- Sign-up race regression test

### Schema
- `schema.sql` promoted to a baseline migration, so a project can be
  provisioned from zero. This closes the drift where `on_auth_user_created`
  existed only in `schema.sql` and never in a migration.

### Code quality
- **0 analyzer issues, down from 169.** CI is now fatal on everything.
- All 36 `use_build_context_synchronously` sites fixed — context-dependent
  objects are resolved before the first `await`, so a user navigating away
  mid-request can no longer crash the screen
- Radio widgets migrated to `RadioGroup`
- `withOpacity` deprecations migrated to `withValues`
- `dart format` enforced in CI; `require_trailing_commas` removed (it fights
  the current formatter)
- Dead error-handling branches removed

---

## Known gaps (not blocking)

- Live database may still contain migrations (`20250828152200/152300/152400`)
  that exist in no local file. Checked locally (2026-08-28): no trace of them
  in migrations, `schema.sql`, or git history — run `supabase migration list
  --linked` once linked and reconcile from what the live project actually has.
- Timezone for the email digest is captured silently from the device's UTC
  offset (`EmailPreferencesService.deviceOffsetTimezone`); there's no explicit
  picker in Settings yet, and non-whole-hour offsets (e.g. UTC+5:30) fall back
  to UTC.

See [UNIMPLEMENTED_FEATURES.md](UNIMPLEMENTED_FEATURES.md) for the feature
backlog.

---

## Documentation

| Document | Purpose |
|---|---|
| [README.md](README.md) | Overview and quick start |
| [SECURITY.md](SECURITY.md) | Credential handling, guards, incident record |
| [docs/RELEASE.md](docs/RELEASE.md) | How releases work; one-time setup |
| [TESTING_GUIDE.md](TESTING_GUIDE.md) | The two test suites |
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) | Local setup and structure |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design and schema |
| [USER_GUIDE.md](USER_GUIDE.md) | End-user documentation |
| [UNIMPLEMENTED_FEATURES.md](UNIMPLEMENTED_FEATURES.md) | Backlog |
| [docs/history/](docs/history/) | Superseded documents, kept for context |
