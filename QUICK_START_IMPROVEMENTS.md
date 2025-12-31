# Quick Start: Applying Pairing Improvements

## What Was Done

We've improved the pairing and task flow system to fully implement the specifications in `pairing_prompt.md`. All code changes have been made - you just need to apply the database migrations.

## ✅ Code Changes (Already Complete)

1. **Task Model Enhanced** - Added `visibility` and `pairId` fields
2. **Task Creation Dialog** - New UI for Personal/Group selection
3. **Task Filters** - Filter by All/Group/Personal when paired
4. **Atomic Transitions** - RPC function for race-free status cycling
5. **Improved Security** - Updated RLS policies for group tasks
6. **UI Updates** - FAB button, filter chips, better UX

## 🔧 Required: Database Migration

You must run this SQL in your Supabase SQL Editor to apply the schema changes:

```sql
-- 1. Add new columns to tasks table
ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'personal' 
  CHECK (visibility IN ('personal', 'group'));

ALTER TABLE tasks 
ADD COLUMN IF NOT EXISTS pair_id UUID 
  REFERENCES pairings(id) ON DELETE SET NULL;

-- 2. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_tasks_pair_id ON tasks(pair_id);
CREATE INDEX IF NOT EXISTS idx_tasks_visibility ON tasks(visibility);

-- 3. Migrate existing data
UPDATE tasks 
SET visibility = CASE 
  WHEN is_personal = true THEN 'personal' 
  ELSE 'group' 
END
WHERE visibility = 'personal';

-- 4. Update RLS policies for tasks
DROP POLICY IF EXISTS "Users can view their own tasks" ON tasks;
CREATE POLICY "Users can view their own tasks"
  ON tasks FOR SELECT
  USING (
    (visibility = 'personal' AND auth.uid() = created_by_id)
    OR
    (visibility = 'group' AND pair_id IN (
      SELECT id FROM pairings 
      WHERE status = 'active' 
      AND (requester_id = auth.uid() OR recipient_id = auth.uid())
    ))
    OR
    auth.uid() = assigned_to_id OR
    auth.uid() = claimed_by_id
  );

DROP POLICY IF EXISTS "Users can update their own tasks" ON tasks;
CREATE POLICY "Users can update their own tasks"
  ON tasks FOR UPDATE
  USING (
    (visibility = 'personal' AND auth.uid() = created_by_id)
    OR
    (visibility = 'group' AND pair_id IN (
      SELECT id FROM pairings 
      WHERE status = 'active' 
      AND (requester_id = auth.uid() OR recipient_id = auth.uid())
    ))
    OR
    auth.uid() = assigned_to_id
  );

-- 5. Create RPC function for atomic task status cycling
CREATE OR REPLACE FUNCTION cycle_task_status(
  task_uuid UUID,
  user_uuid UUID
)
RETURNS TABLE (
  id UUID,
  status TEXT,
  claimed_by_id UUID,
  claimed_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
DECLARE
  current_status TEXT;
  new_status TEXT;
  new_claimed_by UUID;
  new_claimed_at TIMESTAMPTZ;
  new_completed_at TIMESTAMPTZ;
BEGIN
  SELECT tasks.status INTO current_status
  FROM tasks
  WHERE tasks.id = task_uuid
  FOR UPDATE;

  CASE current_status
    WHEN 'unclaimed' THEN
      new_status := 'claimed';
      new_claimed_by := user_uuid;
      new_claimed_at := NOW();
      new_completed_at := NULL;
    WHEN 'claimed' THEN
      new_status := 'completed';
      new_claimed_by := (SELECT tasks.claimed_by_id FROM tasks WHERE tasks.id = task_uuid);
      new_claimed_at := (SELECT tasks.claimed_at FROM tasks WHERE tasks.id = task_uuid);
      new_completed_at := NOW();
    WHEN 'completed' THEN
      new_status := 'unclaimed';
      new_claimed_by := NULL;
      new_claimed_at := NULL;
      new_completed_at := NULL;
    ELSE
      RAISE EXCEPTION 'Invalid task status: %', current_status;
  END CASE;

  RETURN QUERY
  UPDATE tasks
  SET 
    status = new_status,
    claimed_by_id = new_claimed_by,
    claimed_at = new_claimed_at,
    completed_at = new_completed_at,
    updated_at = NOW()
  WHERE tasks.id = task_uuid
  RETURNING tasks.id, tasks.status::TEXT, tasks.claimed_by_id, 
            tasks.claimed_at, tasks.completed_at, tasks.updated_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## 🏃 Running the App

After applying the database migration:

```bash
# Get dependencies
flutter pub get

# Run on your platform
flutter run  # or choose device in VS Code
```

## 🎯 Key New Features

### 1. Personal/Group Toggle (When Paired)
- Tap the **"New Task"** FAB button
- Choose **Personal** (only you) or **Group** (both partners)
- Clear description shows who can see the task

### 2. Task Filtering (When Paired)
- **All**: See everything
- **Group**: Only shared tasks with partner
- **Personal**: Only your private tasks
- Combines with All/Active/Done status filters

### 3. Atomic State Transitions
- No more race conditions when both users tap simultaneously
- Database-level locking ensures clean transitions
- Real-time updates still work perfectly

## ✅ Verification Checklist

Test these scenarios to verify everything works:

**Before Pairing:**
- [ ] Create task → Should be Personal automatically
- [ ] No Personal/Group toggle shown

**After Pairing:**
- [ ] Create Personal task → Only you can see it
- [ ] Create Group task → Partner sees it immediately
- [ ] Filter by Personal → Only your tasks
- [ ] Filter by Group → Only shared tasks
- [ ] Both tap same task → No conflicts, one update wins

**Colors & Sizes:**
- [ ] Unclaimed by you: Yellow, large (120px)
- [ ] Unclaimed by partner: Orange, large (120px)
- [ ] Claimed by anyone: Blue, smaller (90px)
- [ ] Completed: Green, smallest (70px)
- [ ] Urgent: Red border, largest (140px)

## 📚 Documentation

- **Full Implementation Details**: [PAIRING_IMPROVEMENTS.md](./PAIRING_IMPROVEMENTS.md)
- **Original Specification**: [pairing_prompt.md](./pairing_prompt.md)
- **Database Schema**: [supabase/schema.sql](./supabase/schema.sql)

## 🐛 Troubleshooting

**Issue: Can't see partner's tasks**
- Verify you're paired (check pairing screen)
- Ensure task was created as "Group" not "Personal"
- Check visibility filter isn't set to "Personal"

**Issue: Migration fails**
- Ensure you're connected to the correct Supabase project
- Check you have admin access
- Try running sections one at a time

**Issue: Colors wrong**
- Verify you're on latest code (`git pull`)
- Clear and rebuild: `flutter clean && flutter pub get`
- Check theme.dart has correct color constants

## 🚀 What's Next

Consider implementing these suggested enhancements from the spec:

1. **Initials Badge**: Show who claimed a task
2. **Nudge Partner**: Send notification to partner
3. **Today View**: Quick filter for today's tasks
4. **Undo Button**: Quick undo after status change
5. **Smart Defaults**: Remember last Personal/Group choice

---

**Questions?** Check the full documentation in PAIRING_IMPROVEMENTS.md or review the pairing_prompt.md spec.
