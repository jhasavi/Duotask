# DuoTask Production Roadmap

*Last updated: August 28, 2026*

## Where we are

v1.2.0 features are complete. What was missing was not features — it was the
ability to release them safely. That is now built:

- Deploys happen from CI, from the commit being deployed
- The pairing and sign-up flows are covered by automated tests
- Secrets cannot reach a bundle or a deployed URL without failing the build
- The database schema can be provisioned from zero

Three things still need a human. See
[PROJECT_STATUS.md](PROJECT_STATUS.md#-blocking-before-release):

1. Rotate the credentials that were publicly exposed
2. Redeploy — production still serves a bundle from before the sign-up fix
3. Add the CI secrets that make the automated pipeline live

## v1.2.0 feature work (shipped)

| # | Improvement | Status |
|---|-------------|--------|
| 1 | Test infrastructure (`.env.example` asset, icons dir, widget tests) | ✅ |
| 2 | GitHub Actions CI | ✅ |
| 3 | Nudge UI — long-press menu, send dialog, inbox screen | ✅ |
| 4 | Nudge badge + real-time notification snackbar | ✅ |
| 5 | Email preferences toggle in Settings | ✅ |
| 6 | Task owner initials badge on claimed bubbles | ✅ |
| 7 | Undo snackbar after task completion | ✅ |
| 8 | Today view filter chip | ✅ |
| 9 | Group task creation confirmation dialog | ✅ |
| 10 | Remember last Personal/Group visibility choice | ✅ |
| 11 | Pull-to-refresh on home screen | ✅ |
| 12 | Task search by title | ✅ |
| 13 | Smart task sorting (urgent → due date → recent) | ✅ |
| 14 | Offline banner with Retry button | ✅ |
| 15 | Service error messages shown to user | ✅ |
| 16 | App version from config in Settings | ✅ |
| 17 | Task completion revert API (`revertCompletion`) | ✅ |
| 18 | Email preferences service with Supabase upsert | ✅ |
| 19 | Unit tests for task sort/search utilities | ✅ |
| 20 | Documentation update | ✅ |

## Release engineering (shipped August 2026)

| # | Improvement | Status |
|---|-------------|--------|
| 21 | Removed publicly-served `.env` from the web bundle | ✅ |
| 22 | Config injected via `--dart-define`; nothing secret ships to clients | ✅ |
| 23 | `service_role` key removed from test code | ✅ |
| 24 | Cron migrations read credentials from Supabase Vault | ✅ |
| 25 | Password change requires and verifies the current password | ✅ |
| 26 | Hermetic and live-backend test suites separated | ✅ |
| 27 | Pairing flow automated (4 tests) | ✅ |
| 28 | `schema.sql` promoted to a baseline migration | ✅ |
| 29 | Migrations applied by CI, not by hand | ✅ |
| 30 | Automated deploy from source + post-deploy smoke test | ✅ |
| 31 | Secret scanning in CI and at build time | ✅ |
| 32 | `flutter analyze` fatal on everything — 0 issues, down from 169 | ✅ |
| 33 | All 36 `use_build_context_synchronously` crash risks fixed | ✅ |
| 34 | Radio widgets migrated to `RadioGroup`; `dart format` enforced in CI | ✅ |

## v1.3 feature work (shipped 2026-08-28)

| # | Improvement | Status |
|---|-------------|--------|
| 35 | Per-user timezone for the daily email digest (cron now runs hourly; edge function sends each user at their local `email_time`) | ✅ |
| 36 | Task tags — add, remove, search, and filter by tag | ✅ |
| 37 | Monthly/yearly recurrence, plus an optional recurrence end date | ✅ |

## App store readiness (in progress)

| # | Improvement | Status |
|---|-------------|--------|
| 38 | Push notifications for nudges (FCM v1 API, device_tokens table, send-nudge-push edge function, client wiring) | Code done — needs a real Firebase project. See [docs/PUSH_NOTIFICATIONS_SETUP.md](docs/PUSH_NOTIFICATIONS_SETUP.md) |
| 39 | Real app icon on Android/iOS (was the default Flutter logo) + the web favicon/PWA icons, which didn't exist at all | ✅ |
| 40 | Real app identifier — `com.namasteneedham.duotask`, off the `com.example.duotask` Flutter placeholder, on every platform | ✅ |
| 41 | Fixed the Android build — it couldn't compile at all (missing core library desugaring for `flutter_local_notifications`, and `speech_to_text` using a retired Flutter embedding API; removed the latter, unused anywhere in `lib/`) | ✅ |

Still needed before a real store submission: a release signing config
(the release build type currently signs with the **debug** keystore —
fine for local testing, not acceptable for Play Store), and an actual
device/simulator run to eyeball the mobile UI once Xcode is set up.

## Next phase

- Offline task queue with sync
- Analytics dashboard
- Multi-partner (team) support
- Timezone picker in Settings (today the timezone is captured silently from
  the device's UTC offset on first load — see `EmailPreferencesService`)

## Engineering backlog

- Reconcile any live migrations not present in `supabase/migrations/`
- Stop committing `build/web` once a CI deploy has run green
