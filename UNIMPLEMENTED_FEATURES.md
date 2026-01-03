# 📝 Unimplemented Features (Planned but Not Yet Live)

## Overview
This document lists features that have **backend support** but are **missing UI integration** or are **planned for future releases**.

---

## ✅ Backend Ready, UI Pending

### 1. 👉 Nudge System
**Status:** Backend complete, UI not integrated

**What Works:**
- ✅ `nudges` table created in database
- ✅ RLS policies set up
- ✅ `NudgeService` fully implemented with:
  - `sendNudge()` - Send nudge to partner
  - `loadNudges()` - Fetch nudges for user
  - `markAsRead()` - Mark nudge as read
  - `markAllAsRead()` - Mark all as read
  - Real-time subscriptions working
- ✅ Service registered in `main.dart` MultiProvider

**What's Missing:**
- ❌ Long-press on task bubbles to send nudge
- ❌ Nudge sending dialog/modal
- ❌ Incoming nudge notification (snackbar/banner)
- ❌ Nudge inbox/list view
- ❌ Unread nudge badge in UI

**Implementation Location:**
- Backend: `lib/services/nudge_service.dart` (229 lines)
- Database: `migrations/v1.1_ownership_nudges.sql` (nudges table)

**Suggested Implementation:**
```dart
// In home_screen.dart or task_bubble.dart
onLongPress: () {
  showDialog(
    context: context,
    builder: (context) => NudgeDialog(
      task: task,
      partnerId: pairingService.partner?.id,
      onSend: (message) {
        nudgeService.sendNudge(
          pairId: pairingService.currentPair!.id,
          taskId: task.id,
          fromUserId: authService.currentUser!.id,
          toUserId: pairingService.partner!.id,
          fromUserName: authService.currentUser!.displayName!,
          taskTitle: task.title,
        );
      },
    ),
  );
}
```

---

### 2. 📧 Email Preferences UI
**Status:** Backend working, no user-facing controls

**What Works:**
- ✅ Daily email digest function deployed
- ✅ `email_preferences` table in database
- ✅ Users can receive emails (enabled via SQL)
- ✅ Cron job sends emails at 8 AM UTC

**What's Missing:**
- ❌ Settings UI to toggle emails on/off
- ❌ Time selection for email delivery
- ❌ Frequency selection (daily/weekly/never)
- ❌ Email preview/test button

**Database Schema:**
```sql
email_preferences (
  user_id UUID PRIMARY KEY,
  daily_email_enabled BOOLEAN DEFAULT true,
  preferred_time TIME DEFAULT '08:00:00',
  last_email_sent_at TIMESTAMP,
  timezone TEXT DEFAULT 'UTC'
)
```

**Suggested Implementation:**
Add to [lib/screens/settings_screen.dart](lib/screens/settings_screen.dart):
```dart
ListTile(
  title: Text('Daily Email Digest'),
  subtitle: Text('Receive task summary at 8 AM'),
  trailing: Switch(
    value: emailEnabled,
    onChanged: (value) {
      // Update email_preferences table
    },
  ),
)
```

---

### 3. 🏷️ Task Owner Display
**Status:** Data available, not shown in UI

**What Works:**
- ✅ `current_claimed_by` field tracks owner
- ✅ Ownership lock enforces only owner can complete

**What's Missing:**
- ❌ Show "Owned by <name>" label on claimed tasks
- ❌ Display claimer initials badge on bubble
- ❌ Partner name fetch from users table

**Suggested Implementation:**
```dart
// In task_bubble.dart
if (task.currentClaimedBy != null) {
  Positioned(
    top: 4,
    right: 4,
    child: CircleAvatar(
      radius: 12,
      child: Text(
        getClaimerInitials(task.currentClaimedBy),
        style: TextStyle(fontSize: 10),
      ),
    ),
  )
}
```

---

## 🚀 Planned for Future Releases

### 4. ⏪ Undo Snackbar
**Status:** Not implemented

**What It Does:**
- Show "Task completed" snackbar with Undo button
- Quick undo after status change (3-5 second window)

**How to Implement:**
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Task completed'),
    action: SnackBarAction(
      label: 'Undo',
      onPressed: () {
        taskService.cycleTaskStatus(task.id, userId);
      },
    ),
  ),
);
```

---

### 5. 📅 Today View
**Status:** Not implemented

**What It Does:**
- Filter to show only tasks due today
- Quick access from home screen

**How to Implement:**
Add filter chip or tab:
```dart
FilterChip(
  label: Text('Today'),
  selected: showTodayOnly,
  onSelected: (selected) {
    setState(() {
      showTodayOnly = selected;
    });
  },
)
```

---

### 6. ✅ Confirmation Before Group Task Creation
**Status:** Not implemented

**What It Does:**
- Prevent accidental group task creation
- Show confirmation dialog when creating group task

---

### 7. 🔔 Push Notifications (Mobile)
**Status:** FCM setup pending

**What's Needed:**
- Firebase Cloud Messaging setup
- iOS APNs certificates
- Android FCM configuration
- Notification handlers

---

### 8. 📊 Task Analytics
**Status:** Not implemented

**Possible Features:**
- Completion rate graphs
- Streak tracking
- Weekly/monthly summaries
- Partner collaboration stats

---

### 9. 🗂️ Task Categories/Tags
**Status:** Not implemented

**What It Does:**
- Add tags to tasks (e.g., #home, #work, #urgent)
- Filter by tags
- Color-coded categories

---

### 10. 📎 File Attachments
**Status:** Not implemented

**What It Does:**
- Attach images/files to tasks
- Uses Supabase Storage
- Share receipts, photos, documents

---

## 🎯 Quick Win Implementations

These are the **easiest** features to implement next:

1. **Nudge Button (1-2 hours)**
   - Backend ready, just needs UI
   - Long-press → dialog → call nudgeService.sendNudge()

2. **Email Toggle in Settings (30 minutes)**
   - Simple switch widget
   - Update email_preferences table

3. **Task Owner Label (1 hour)**
   - Fetch user name from users table
   - Display "Owned by <name>" on claimed tasks

4. **Today View Filter (30 minutes)**
   - Add filter chip
   - Filter tasks by due_date == today

5. **Undo Snackbar (1 hour)**
   - Show snackbar after completion
   - Store previous state for undo

---

## 🐛 Known Limitations

1. **Timezone Support**
   - Email cron uses UTC (8 AM UTC)
   - Weekly summary uses device timezone
   - Need unified timezone handling

2. **Recurring Tasks**
   - Only supports daily and weekly
   - No monthly/yearly
   - No end date for recurrence

3. **Past Partners**
   - Shows max 10 most recent
   - No pagination
   - No search functionality

4. **Offline Mode**
   - No offline task creation
   - Requires internet connection

---

## 📚 Reference Files

**Nudge System:**
- [lib/services/nudge_service.dart](lib/services/nudge_service.dart)
- [migrations/v1.1_ownership_nudges.sql](migrations/v1.1_ownership_nudges.sql)

**Email System:**
- [supabase/functions/daily-email-digest/index.ts](supabase/functions/daily-email-digest/index.ts)
- [supabase/functions/daily-email-digest/README.md](supabase/functions/daily-email-digest/README.md)

**Documentation:**
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - Lines 225-243
- [PAIRING_IMPROVEMENTS.md](PAIRING_IMPROVEMENTS.md) - Lines 196-204
- [QUICK_START_IMPROVEMENTS.md](QUICK_START_IMPROVEMENTS.md) - Lines 209-218

---

*Last Updated: January 3, 2026*  
*After fixing duplicate filter controls and task overlap issues*
