# DuoTask - Project Status

*Last Updated: June 25, 2026*

## Current Version: 1.2.0

### GitHub Sync
- **Branch**: `main` — synced with `origin/main`
- **CI**: GitHub Actions runs `flutter analyze` and `flutter test` on every push
- **Tests**: 76 passing

---

## ✅ Completed in v1.2.0

### Production Features
- Nudge system UI (send, inbox, badge, real-time notifications)
- Email digest preferences toggle in Settings
- Task owner initials on claimed bubbles
- Undo snackbar after completing tasks
- Today filter, search, pull-to-refresh
- Group task creation confirmation
- Remember last Personal/Group choice
- Smart task sorting (urgent first)
- Offline retry button
- CI/CD pipeline

### Infrastructure Fixes
- Test asset bundle uses `.env.example` (no missing `.env` in CI)
- `assets/icons/` directory created
- Widget tests updated for current app structure
- App version bumped to 1.2.0

---

## 🔄 Still Pending (Manual Steps)

### 1. Database Migrations
Run these in Supabase SQL Editor:
- `migrations/pairing_improvements.sql`
- `migrations/v1.1_ownership_nudges.sql`
- `migrations/v1.2_daily_email.sql`
- `migrations/init_email_preferences.sql`

### 2. End-to-End Testing
- [ ] Pair two users and verify bidirectional visibility
- [ ] Create personal vs group tasks
- [ ] Test nudge send/receive
- [ ] Test email digest toggle
- [ ] Test undo after completion

### 3. Deployment
```bash
flutter build web --release
# Deploy build/web to Vercel
```

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [PRODUCTION_ROADMAP.md](PRODUCTION_ROADMAP.md) | 20 improvements + next steps |
| [QUICK_START_IMPROVEMENTS.md](QUICK_START_IMPROVEMENTS.md) | Database migration guide |
| [PAIRING_TEST_GUIDE.md](PAIRING_TEST_GUIDE.md) | Pairing test scenarios |
| [UNIMPLEMENTED_FEATURES.md](UNIMPLEMENTED_FEATURES.md) | Remaining future features |
| [USER_GUIDE.md](USER_GUIDE.md) | End-user documentation |
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) | Developer setup |

---

*Update this file as milestones are completed.*
