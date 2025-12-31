# DuoTask - User Guide

## Welcome to DuoTask! 🎯

DuoTask is a task management app designed for partners who want to collaborate and share responsibilities. Whether you're managing household chores, planning projects, or organizing your life together, DuoTask makes it easy to stay in sync.

## Getting Started

### 1. Sign Up / Sign In

**Visit**: https://duotask.namasteneedham.com

**Sign Up Options**:
- **Email & Password**: Enter your email, create a password (min. 6 characters), and choose a display name
- **Google Account**: Click "Continue with Google" to sign in with your Google account

After signing up, you'll be automatically logged in and taken to your home screen.

---

## Core Features

### 2. Pairing with Your Partner

Before you can share tasks, you need to pair with your partner.

**To Pair**:

**Option A: Share Your Code**
1. Go to **Settings** → **Partner Pairing**
2. Click **"Generate Code"**
3. A unique 8-character code will appear (e.g., `XYZW1234`)
4. Click the **Copy icon** to copy the code
5. Share this code with your partner (text, email, etc.)

**Option B: Enter Partner's Code**
1. Ask your partner to generate their code
2. Go to **Settings** → **Partner Pairing**
3. Scroll to **"Enter Partner's Code"**
4. Type or paste their code
5. Click **"Connect"**

✅ **Success!** You're now paired and can see each other's shared tasks.

---

### 3. Creating Tasks

**From Home Screen**:
1. Click the **"+"** button (bottom right)
2. Fill in task details:
   - **Title**: What needs to be done (e.g., "Buy groceries")
   - **Description** (optional): Add more details
   - **Assign To**: Choose yourself, your partner, or leave unassigned
   - **Priority**: Normal or Urgent (urgent tasks show in red)
   - **Due Date** (optional): Set a deadline
   - **Personal**: Check this if the task is private (partner won't see it)

3. Click **"Create Task"**

---

### 4. Managing Tasks

#### Task Statuses

Tasks flow through three states:

1. **Unclaimed** (Gray)
   - Task is created but no one has started working on it
   - Anyone assigned can claim it

2. **Claimed** (Blue)
   - Someone has started working on the task
   - Shows who claimed it

3. **Completed** (Green)
   - Task is finished
   - Shows who completed it and when

#### Task Actions

**Claim a Task**:
- Open an unclaimed task assigned to you
- Click **"Claim Task"**
- Status changes to "Claimed"

**Complete a Task**:
- Open a claimed task (that you claimed)
- Click **"Mark Complete"**
- Task moves to completed list

**Edit a Task**:
- Open any task you created
- Click **"Edit Task"**
- Modify details and save

**Delete a Task**:
- Open any task you created
- Click **"Delete Task"**
- Confirm deletion

---

### 5. Task Views

**Filter Tasks**:
- **All Tasks**: See everything
- **My Tasks**: Tasks assigned to you
- **Partner's Tasks**: Tasks assigned to your partner
- **Unclaimed**: Tasks waiting to be claimed
- **Claimed**: Tasks in progress
- **Completed**: Finished tasks

**Urgent Tasks**:
- Marked with a red flame icon 🔥
- Appear at the top of lists
- Show "URGENT" label

---

### 6. Personal vs. Shared Tasks

**Shared Tasks** (default):
- Visible to both you and your partner
- Either person can claim
- Great for household chores, errands

**Personal Tasks**:
- Only you can see them
- Your partner has no visibility
- Perfect for individual goals, private to-dos

**To make a task personal**: Check the "Personal" box when creating.

---

### 7. Recurring Tasks

Set tasks to repeat automatically:

- **None**: One-time task (default)
- **Daily**: Repeats every day
- **Weekly**: Repeats every week

When you complete a recurring task, a new one is automatically created for the next cycle.

---

### 8. Managing Your Account

**Settings Screen**:
- **Profile**: View your email and display name
- **Paired With**: See your partner's info
- **Change Password**: Update your password
- **Logout**: Sign out of your account

**To Unpair**:
1. Go to **Settings** → **Partner Pairing**
2. Click **"Disconnect Partner"**
3. Confirm the action

⚠️ **Note**: Unpairing will hide shared tasks, but they're not deleted. If you re-pair later, shared tasks will reappear.

---

## Tips & Best Practices

### 1. **Use Descriptions**
Add context to your tasks so your partner knows exactly what needs to be done.

Example:
- ❌ Title: "Groceries"
- ✅ Title: "Buy groceries"  
  Description: "Milk, bread, eggs, and fruit from Whole Foods"

### 2. **Set Priorities Wisely**
Reserve "Urgent" for truly time-sensitive tasks. Too many urgent tasks = nothing is urgent.

### 3. **Claim Tasks Promptly**
When you start working on a task, claim it right away so your partner knows you've got it.

### 4. **Review Together**
Check your tasks together weekly to stay aligned on priorities.

### 5. **Use Personal Tasks**
Don't clutter shared views with personal items. Keep work tasks, personal goals, etc. as personal.

---

## Troubleshooting

### "Invalid or expired pairing code"
**Solution**: Make sure:
- The code is exactly 8 characters
- The code was just generated (codes don't expire, but make sure it's pending)
- You're not trying to pair with yourself

### Can't see partner's tasks
**Check**:
- You're actually paired (Settings → Partner Pairing should show partner's name)
- Tasks aren't marked as "Personal"
- You're not filtering by "My Tasks" only

### "Sign in successful" but stuck on login screen
**Solution**: 
- Clear browser cache and try again
- Make sure you're using the latest deployment
- Check browser console (F12) for errors

### Tasks not updating in real-time
**Check**:
- You have internet connection
- Refresh the page
- Sign out and back in

---

## Keyboard Shortcuts

- **New Task**: Click the "+" button (no keyboard shortcut yet)
- **Refresh**: Pull down or refresh page
- **Search**: Use browser's find (Cmd/Ctrl + F)

---

## Privacy & Security

### Your Data
- All data is stored securely on Supabase (encrypted at rest)
- Only you and your paired partner can see shared tasks
- Personal tasks are never shared
- We don't sell or share your data with third parties

### Authentication
- Passwords are hashed and never stored in plain text
- Google OAuth uses secure industry-standard protocols
- Sessions expire after inactivity for security

### Pairing
- Pairing codes are unique and single-use
- Once accepted, the code cannot be reused
- You can only be paired with one person at a time

---

## FAQs

**Q: Can I pair with multiple partners?**  
A: Not currently. DuoTask supports 1-to-1 pairing only.

**Q: Can I undo completing a task?**  
A: Not yet, but this feature is planned. For now, you can create a new task.

**Q: What happens if I delete my account?**  
A: All your tasks are deleted, and your partner is automatically unpaired.

**Q: Can I use DuoTask offline?**  
A: Not yet. Offline mode is planned for future releases.

**Q: Is there a mobile app?**  
A: Currently web-only, but native iOS/Android apps are planned.

**Q: How do I export my tasks?**  
A: Export feature coming soon. For now, you can manually copy task details.

---

## Need Help?

**Issues or Questions?**
- Check the browser console (F12) for error messages
- Email: support@duotask.namasteneedham.com
- Report bugs: Create an issue on GitHub (if available)

---

## Updates

DuoTask is actively being developed. New features coming soon:
- 📱 Mobile apps (iOS & Android)
- 🔔 Push notifications
- 💬 In-app messaging
- 📊 Task analytics and insights
- 📎 File attachments
- 🎨 Custom themes

---

**Version**: 1.0.0  
**Last Updated**: December 23, 2025  
**Website**: https://duotask.namasteneedham.com

---

## Quick Reference Card

```
┌─────────────────────────────────────┐
│         DUOTASK QUICK START         │
├─────────────────────────────────────┤
│ 1. Sign Up / Sign In                │
│    → Email or Google                │
│                                     │
│ 2. Pair with Partner                │
│    → Generate Code OR Enter Code    │
│                                     │
│ 3. Create Task                      │
│    → Click "+" button               │
│    → Fill details                   │
│    → Assign & Save                  │
│                                     │
│ 4. Manage Tasks                     │
│    → Claim → Work → Complete        │
│                                     │
│ 5. Stay Synced                      │
│    → Real-time updates              │
│    → Filter views                   │
└─────────────────────────────────────┘

Task Flow:
  Unclaimed → Claimed → Completed
     ⬇️         ⬇️          ✅
   (gray)    (blue)     (green)
```

---

Happy tasking! 🎉
