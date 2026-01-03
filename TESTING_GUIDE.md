# DuoTask v1.1 & v1.2 Testing Guide

## 🎯 Testing Status

### Deployment Status
- ✅ Web app deployed to Vercel
- ✅ Database migrations executed (v1.1 & v1.2)
- ✅ Email edge function deployed
- ⏳ Email cron job setup (pending SQL execution)
- ⏳ Email preferences initialization (pending SQL execution)

### Test Accounts
- User 1: jhasavi@gmail.com
- User 2: munujha@gmail.com

---

## 📋 Test Plan

### 1. Core Features (v1.1)

#### A. Daily Check-In Banner
**Steps:**
1. Login as jhasavi@gmail.com
2. Verify paired with munujha@gmail.com
3. Check home screen top section
4. Look for banner showing:
   - Group task counts (unclaimed/claimed)
   - Top 3 urgent/nearest-due tasks
   - "Focus Mode" button
   - "Hide for today" button

**Expected Results:**
- ✅ Banner appears only when paired
- ✅ Shows accurate task counts
- ✅ Focus Mode switches to "Paired" tab
- ✅ Hide button removes banner until tomorrow
- ✅ Banner reappears next day

#### B. Personal/Paired Tabs
**Steps:**
1. Check home screen tabs
2. Verify two tabs: "Personal" and "Paired"
3. Click Personal tab
4. Click Paired tab
5. Create a personal task
6. Create a group task
7. Switch between tabs

**Expected Results:**
- ✅ Personal tab shows only personal tasks
- ✅ Paired tab shows only group/shared tasks
- ✅ Tab label says "Paired" when connected
- ✅ Tasks appear in correct tab
- ✅ No cross-contamination between tabs

#### C. Ownership Lock
**Steps:**
1. Login as jhasavi@gmail.com
2. Go to Paired tab
3. Create a group task
4. Click to claim it (status: claimed, owner: you)
5. Logout and login as munujha@gmail.com
6. Find the same task (should show as claimed by jhasavi)
7. Try to mark it complete

**Expected Results:**
- ✅ Cannot complete task claimed by partner
- ✅ Error message: "Only the task owner can complete this task"
- ✅ Task status remains "claimed"
- ✅ Owner can complete their own claimed tasks

#### D. Pairing Management (Bug Fix)
**Steps:**
1. Login as jhasavi@gmail.com
2. Go to Settings
3. Verify "Partner Pairing" section shows munujha@gmail.com
4. Click "Unpair"
5. Confirm unpair
6. Verify pairing removed
7. Logout and login as munujha@gmail.com
8. Go to Settings
9. Verify pairing also removed for munujha

**Expected Results:**
- ✅ Both users show as unpaired
- ✅ No stale pairing data
- ✅ Can create new pairing code
- ✅ Settings shows pending code with copy button

#### E. Weekly Summary (Time-based)
**Note:** This requires waiting until Sunday 9 AM or manually changing device time.

**Steps:**
1. Wait for Sunday at 9 AM (or change system time)
2. Login as jhasavi@gmail.com
3. Open app

**Expected Results:**
- ✅ Modal appears showing weekly stats
- ✅ Shows tasks completed by you
- ✅ Shows tasks completed by partner
- ✅ Shows total tasks completed together
- ✅ Only appears once per week

---

### 2. Email Notifications (v1.2)

#### A. Database Setup
**Steps:**
1. Go to: https://supabase.com/dashboard/project/xqhlnuvpogiolzkucupt/sql/new
2. Run `migrations/init_email_preferences.sql`
3. Verify output shows both users enabled
4. Run `migrations/setup_email_cron.sql`
5. Verify cron job created

**Expected Results:**
- ✅ email_preferences table has entries for all users
- ✅ daily_email_enabled = TRUE by default
- ✅ Cron job scheduled for 8 AM UTC daily

#### B. Manual Email Test
**Steps:**
1. Create some tasks (personal and group) for jhasavi@gmail.com
2. Run manual trigger:
   ```bash
   curl -X POST 'https://xqhlnuvpogiolzkucupt.supabase.co/functions/v1/daily-email-digest' \
     -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhxaGxudXZwb2dpb2x6a3VjdXB0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE5MTA1NzgsImV4cCI6MjA2NzQ4NjU3OH0.9lw-X6mjpPFfTqpiiTEOpzWZEfqnPkW0ADA6XfbLsNw' \
     -H 'Content-Type: application/json'
   ```
3. Check jhasavi@gmail.com inbox
4. Check munujha@gmail.com inbox

**Expected Results:**
- ✅ Email received at jhasavi@gmail.com
- ✅ Email received at munujha@gmail.com
- ✅ Email contains correct task counts
- ✅ Email has proper HTML formatting
- ✅ Tasks categorized correctly:
  - Personal: Unclaimed, Claimed by you
  - Shared: No one owns, You own, Partner owns
- ✅ Priority tasks marked (urgent vs normal)
- ✅ Due dates displayed correctly
- ✅ Unsubscribe link present

#### C. Email Content Verification
**Check email for:**
- ✅ Subject line: "Your Daily DuoTask Digest - X tasks"
- ✅ Greeting: "Hello, [Name]!"
- ✅ Summary card with total open tasks
- ✅ Personal Tasks section
- ✅ Shared Tasks section (if paired)
- ✅ "Pair up" message (if not paired)
- ✅ Task titles visible
- ✅ Due dates formatted nicely
- ✅ Priority indicators (color-coded borders)
- ✅ Open DuoTask link works
- ✅ Manage preferences link works

---

### 3. Regression Testing

#### A. Existing Features Still Work
- ✅ Task creation (personal & group)
- ✅ Task claiming (I'll do it)
- ✅ Task completion (Done)
- ✅ Task cycling (unclaimed → claimed → completed → unclaimed)
- ✅ Pairing with code
- ✅ Accepting pairing request
- ✅ Real-time task updates
- ✅ Settings screen
- ✅ Profile editing
- ✅ Sign out
- ✅ Google OAuth login

#### B. UI/UX
- ✅ No layout breaks
- ✅ Smooth animations
- ✅ Responsive design
- ✅ Dark mode (if applicable)
- ✅ Loading states
- ✅ Error messages
- ✅ Offline banner

---

## 🐛 Known Issues to Watch For

1. **Weekly Summary Timing**
   - May need timezone adjustment
   - SharedPreferences key format: "YYYY-Www-dd"
   - Reset if needed: Clear app data

2. **Email Cron Job**
   - First run: Tomorrow at 8 AM UTC (3 AM EST)
   - Check logs: `SELECT * FROM cron.job_run_details ORDER BY start_time DESC;`
   - If fails: Check function logs in Supabase Dashboard

3. **Ownership Lock**
   - Only applies to group tasks
   - Personal tasks not affected
   - Unclaimed tasks can be claimed by anyone

---

## 📊 SQL Queries for Testing

### Check Email Preferences
```sql
SELECT u.email, u.display_name, ep.daily_email_enabled, ep.last_email_sent_at
FROM users u
LEFT JOIN email_preferences ep ON u.id = ep.user_id
ORDER BY u.email;
```

### Check Pairing Status
```sql
SELECT 
  u1.email as requester_email,
  u2.email as recipient_email,
  p.status,
  p.pairing_code,
  p.created_at,
  p.accepted_at
FROM pairings p
JOIN users u1 ON p.requester_id = u1.id
LEFT JOIN users u2 ON p.recipient_id = u2.id
ORDER BY p.created_at DESC
LIMIT 10;
```

### Check Cron Job Status
```sql
-- View scheduled jobs
SELECT * FROM cron.job WHERE jobname = 'daily-email-digest';

-- View recent runs
SELECT * FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'daily-email-digest')
ORDER BY start_time DESC 
LIMIT 10;
```

### Get Daily Email Data for User
```sql
-- Replace USER_ID with actual UUID
SELECT get_daily_email_data('USER_ID');
SELECT get_daily_email_tasks('USER_ID');
```

---

## ✅ Final Checklist

### Pre-Deployment
- [x] v1.1 migration executed
- [x] v1.2 migration executed
- [x] Email edge function deployed
- [ ] Email preferences initialized
- [ ] Email cron job scheduled
- [ ] Vercel deployment successful

### Post-Deployment Testing
- [ ] Login works for both test users
- [ ] Pairing shows correctly
- [ ] Tasks display in correct tabs
- [ ] Ownership lock enforced
- [ ] Unpair works for both users
- [ ] Daily banner appears
- [ ] Email test successful

### Production Ready
- [ ] All tests passed
- [ ] No critical bugs
- [ ] Email unsubscribe works
- [ ] Documentation updated
- [ ] Users notified of new features

---

## 🚀 Quick Test Commands

```bash
# Test email function
curl -X POST 'https://xqhlnuvpogiolzkucupt.supabase.co/functions/v1/daily-email-digest' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhxaGxudXZwb2dpb2x6a3VjdXB0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE5MTA1NzgsImV4cCI6MjA2NzQ4NjU3OH0.9lw-X6mjpPFfTqpiiTEOpzWZEfqnPkW0ADA6XfbLsNw' \
  -H 'Content-Type: application/json'

# Check Vercel deployment
open https://duotask-seven.vercel.app

# Check Supabase Dashboard
open https://supabase.com/dashboard/project/xqhlnuvpogiolzkucupt
```

---

## 📞 Support

If issues occur:
1. Check Supabase function logs
2. Check Vercel deployment logs
3. Check browser console for errors
4. Verify database migrations ran successfully
5. Test with fresh user account if needed
