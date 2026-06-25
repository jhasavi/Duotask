# Unimplemented Features

*Last Updated: June 25, 2026*

Features completed in v1.2.0 have been removed from this list. See [PRODUCTION_ROADMAP.md](PRODUCTION_ROADMAP.md) for what was shipped.

---

## Remaining for Future Releases

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
- Email cron currently UTC
- Need per-user timezone for digest delivery

---

## Manual Setup Still Required

1. **Database migrations** — Run SQL in `migrations/` folder
2. **Resend API** — For daily email digest (`supabase/functions/daily-email-digest/`)
3. **Firebase** — For mobile push notifications

---

*See [PRODUCTION_ROADMAP.md](PRODUCTION_ROADMAP.md) for the full v1.2.0 changelog.*
