# DuoTask Production Roadmap

*Last updated: August 14, 2026*

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
| 32 | `flutter analyze` fatal on warnings again (0 errors, 0 warnings) | ✅ |

## Next phase (v1.3)

- Push notifications (FCM) — needs Firebase setup and APNs certificates
- Offline task queue with sync
- Task categories/tags
- Monthly/yearly recurrence with end dates
- Analytics dashboard
- Multi-partner (team) support
- Per-user timezone for the daily email digest (currently fixed at 08:00 UTC)

## Engineering backlog

- 36 `use_build_context_synchronously` analyzer infos — real crash risk in
  edge cases; needs per-site review
- 12 Radio `groupValue`/`onChanged` deprecations — migrate to `RadioGroup`
- Reconcile any live migrations not present in `supabase/migrations/`
- Stop committing `build/web` once a CI deploy has run green
