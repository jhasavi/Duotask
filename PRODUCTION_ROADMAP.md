# DuoTask Production Roadmap

*Last Updated: June 25, 2026*

## Where We Left Off

The project was blocked on three fronts:

1. **Database migrations not applied** — SQL scripts in `migrations/` need to be run in Supabase (pairing improvements, nudges, email preferences).
2. **Test/build infrastructure broken** — Missing `.env` asset, missing `assets/icons/`, stale `widget_test.dart`.
3. **Backend-ready features missing UI** — Nudge system, email preferences, task owner display, undo, today filter, and more.

## 20 Production-Ready Improvements (v1.2.0)

| # | Improvement | Status |
|---|-------------|--------|
| 1 | Fix test infrastructure (`.env.example` asset, icons dir, widget tests) | ✅ Done |
| 2 | GitHub Actions CI (analyze + test on push) | ✅ Done |
| 3 | Nudge UI — long-press menu, send dialog, inbox screen | ✅ Done |
| 4 | Nudge badge + real-time incoming notification snackbar | ✅ Done |
| 5 | Email preferences toggle in Settings | ✅ Done |
| 6 | Task owner initials badge on claimed bubbles | ✅ Done |
| 7 | Undo snackbar after task completion | ✅ Done |
| 8 | Today view filter chip | ✅ Done |
| 9 | Group task creation confirmation dialog | ✅ Done |
| 10 | Remember last Personal/Group visibility choice | ✅ Done |
| 11 | Pull-to-refresh on home screen | ✅ Done |
| 12 | Task search by title | ✅ Done |
| 13 | Smart task sorting (urgent → due date → recent) | ✅ Done |
| 14 | Offline banner with Retry button | ✅ Done |
| 15 | Service error messages shown to user | ✅ Done |
| 16 | App version from config in Settings | ✅ Done |
| 17 | Task completion revert API (`revertCompletion`) | ✅ Done |
| 18 | Email preferences service with Supabase upsert | ✅ Done |
| 19 | Unit tests for task sort/search utilities | ✅ Done |
| 20 | Comprehensive documentation update | ✅ Done |

## Still Required Before Full Production

- [ ] Run all SQL migrations in Supabase (see `QUICK_START_IMPROVEMENTS.md`)
- [ ] End-to-end pairing test with two users (see `PAIRING_TEST_GUIDE.md`)
- [ ] Configure Resend API key for daily email digest
- [ ] Set up Firebase for push notifications (mobile)
- [ ] Deploy web build to Vercel

## Next Phase (v1.3)

- Push notifications (FCM)
- Offline task queue with sync
- Task categories/tags
- Monthly recurring tasks
- Analytics dashboard
- Multi-partner (team) support
