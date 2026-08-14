# Unimplemented Features

*Last updated: August 14, 2026*

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

### Task Categories/Tags
- Add tags (#home, #work, #urgent)
- Filter by tags

### File Attachments
- Attach images/files via Supabase Storage

### Task Analytics
- Completion rate graphs
- Streak tracking
- Partner collaboration stats

### Advanced Recurrence
- Monthly/yearly recurrence
- End date for recurring tasks

### Multi-Partner Support
- Teams beyond two people

### Timezone Unification
- The email digest cron fires at a single 08:00 UTC instant for every user
- Needs a per-user timezone and either per-timezone cron rows or an
  hourly job that selects users whose local time is 08:00

---

## Engineering backlog

### Schema reconciliation
The live database was previously modified through the Supabase SQL Editor. It
may contain migrations (`20250828152200`, `20250828152300`, `20250828152400`)
that exist in no local file. Once linked, run `supabase migration list` and
either write the missing migrations or repair the history.

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
