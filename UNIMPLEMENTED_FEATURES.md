# Unimplemented Features

*Last updated: August 28, 2026*

Shipped work has been removed from this list. See
[PRODUCTION_ROADMAP.md](PRODUCTION_ROADMAP.md) for what exists today and
[PROJECT_STATUS.md](PROJECT_STATUS.md) for what blocks release.

---

## Features

### Push Notifications (Mobile)
- Firebase Cloud Messaging setup
- iOS APNs certificates
- Android FCM configuration

### Offline Mode
- Queue task changes locally
- Sync when connection restored

### File Attachments
- Attach images/files via Supabase Storage

### Task Analytics
- Completion rate graphs
- Streak tracking
- Partner collaboration stats

### Multi-Partner Support
- Teams beyond two people

---

## Engineering backlog

### Schema reconciliation
The live database was previously modified through the Supabase SQL Editor. It
may contain migrations (`20250828152200`, `20250828152300`, `20250828152400`)
that exist in no local file. Checked 2026-08-28: no trace of these timestamps
exists anywhere in `supabase/migrations/`, `supabase/schema.sql`, or git
history — they can't be reconstructed locally. Once linked to the live
project, run `supabase migration list --linked` (or `supabase db diff`) and
either write the missing migrations from what's found or repair the history.
Separately, `supabase/schema.sql` itself is stale — it predates the
`email_preferences`/`nudges` migrations and should not be treated as
authoritative; `supabase/migrations/00000000000000_baseline_schema.sql` is.

### Stop committing `build/web`
Tracked only because Vercel currently serves the committed directory. Once a
CI deploy has run green, untrack it — see
[docs/RELEASE.md](docs/RELEASE.md#3-stop-committing-buildweb).

---

## Manual setup still required

1. **CI secrets** — deploy and integration-test credentials. See
   [docs/RELEASE.md](docs/RELEASE.md#one-time-setup).
2. **A dedicated Supabase test project** — integration tests create real users
   and must not run against production.
3. **Supabase Vault secrets** — `project_url` and `anon_key`, for the daily
   email cron job.
4. **Resend API key** — for the daily digest edge function.
5. **Firebase** — for mobile push notifications.
