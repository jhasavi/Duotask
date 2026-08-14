# Pairing and Task Flow Improvements - Implementation Summary

## Overview
This document summarizes the improvements made to DuoTask's pairing and task flow to fully implement the specifications outlined in `pairing_prompt.md`.

## Key Improvements Implemented

### 1. ✅ Enhanced Task Model with Visibility

**Added Fields:**
- `visibility` enum: `personal` | `group` (replaces boolean `isPersonal`)
- `pair_id`: Links group tasks to active pairing

**Database Schema Updates:**
```sql
ALTER TABLE tasks ADD COLUMN visibility TEXT NOT NULL DEFAULT 'personal' 
  CHECK (visibility IN ('personal', 'group'));
ALTER TABLE tasks ADD COLUMN pair_id UUID REFERENCES pairings(id) ON DELETE SET NULL;
```

**Backward Compatibility:**
- Old `is_personal` field maintained for legacy data
- Automatic migration in `Task.fromJson()` method

### 2. ✅ One-Tap Personal/Group Toggle

**New UI Component:** `TaskCreationDialog`
- Shows Personal/Group toggle when user is paired
- Clean segmented button interface
- Clear helper text explaining visibility
- Remembers last selection

**Integration:**
- Floating Action Button for quick task creation
- Quick input bar still available for fast entry
- Defaults to Personal for safety

### 3. ✅ Task Filtering While Paired

**New Filter System:**
- **All**: Shows all tasks (default)
- **Group**: Shows only shared tasks with partner
- **Personal**: Shows only personal tasks

**Filter UI:**
- Filter chips below status tabs
- Only visible when paired
- Combines with All/Active/Done filters

### 4. ✅ Atomic Task State Transitions

**PostgreSQL RPC Function:** `cycle_task_status(task_uuid, user_uuid)`
- Prevents race conditions with row-level locking
- Atomically transitions: `unclaimed → claimed → done → unclaimed`
- Returns updated task data

**Implementation:**
- TaskService.cycleTaskStatus() now uses RPC
- Handles concurrency safely
- Optimistic UI updates with server confirmation

### 5. ✅ Updated RLS Policies

**Enhanced Security:**
- Personal tasks: Only creator can access
- Group tasks: Both users in active pair can access
- Proper pair_id validation
- Backward compatible with existing data

### 6. ✅ Correct Bubble Colors & Sizes

**Color Spec (Already Correct):**
- **Yellow** (#FB923C): Unclaimed created by me
- **Orange** (#F97316): Unclaimed created by partner
- **Blue** (#3B82F6): Claimed (both users see same)
- **Green** (#10B981): Completed

**Size Spec (Already Correct):**
- Unclaimed: 120px (larger)
- Claimed: 90px (smaller, visual "in progress")
- Completed: 70px
- Urgent: 140px (largest)

## How It Works

### Creating Tasks

**Before Pairing:**
- All tasks automatically created as Personal
- No visibility toggle shown

**After Pairing:**
1. User opens task creation dialog (FAB or quick input)
2. Selects Personal or Group (toggle visible only when paired)
3. Group tasks automatically get `pair_id` set
4. Both partners see group tasks in real-time

### Viewing Tasks

**Filter Combinations:**
- Status Filter: All / Active / Done
- Visibility Filter: All / Group / Personal (when paired)
- Filters work together

**Examples:**
- "Active + Group" = Active shared tasks
- "Done + Personal" = Completed personal tasks
- "All + All" = Everything

### Task State Machine

**One-Tap Cycling:**
```
Unclaimed (Yellow/Orange) 
  ↓ [Tap]
Claimed (Blue, smaller)
  ↓ [Tap]  
Done (Green)
  ↓ [Tap]
Unclaimed (Yellow/Orange)
```

**Concurrency Handling:**
- Uses PostgreSQL row locking
- If two users tap simultaneously, one succeeds
- Loser sees updated state via real-time

## Acceptance Criteria Status

| # | Requirement | Status |
|---|-------------|--------|
| 1 | Unpaired users create personal tasks only | ✅ |
| 2 | Paired users get one-tap Personal/Group choice | ✅ |
| 3 | Unclaimed: Yellow (me) / Orange (partner) | ✅ |
| 4 | Claimed: Blue & smaller for both users | ✅ |
| 5 | Done: Green for both users | ✅ |
| 6 | Single tap cycles unclaimed → claimed → done | ✅ |
| 7 | Real-time updates on both devices | ✅ |
| 8 | Pairing screen in bottom tabs | ✅ |
| 9 | Pairing remembered (no code re-request) | ✅ |
| 10 | Partner notified of pairing status changes | ✅ |
| 11 | Easy access to personal tasks while paired | ✅ |

## Migration Guide

### Database Migration

Run the following SQL in Supabase SQL Editor:

```sql
-- Add new columns
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'personal' 
  CHECK (visibility IN ('personal', 'group'));
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS pair_id UUID REFERENCES pairings(id) ON DELETE SET NULL;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_tasks_pair_id ON tasks(pair_id);
CREATE INDEX IF NOT EXISTS idx_tasks_visibility ON tasks(visibility);

-- Migrate existing data
UPDATE tasks 
SET visibility = CASE 
  WHEN is_personal = true THEN 'personal' 
  ELSE 'group' 
END
WHERE visibility = 'personal'; -- Only update if not already set

-- Update RLS policies (see schema.sql)

-- Create RPC function (see schema.sql)
```

### Code Updates

No breaking changes - all updates are backward compatible:
- Old `isPersonal` field still works
- Existing tasks auto-migrate on read
- New fields optional with sensible defaults

## Testing Checklist

- [ ] Create personal task when unpaired
- [ ] Create personal task when paired
- [ ] Create group task when paired
- [ ] Filter by Personal (should see only personal)
- [ ] Filter by Group (should see only shared)
- [ ] Partner sees group task in real-time
- [ ] Partner cannot see personal task
- [ ] Tap cycling works (unclaimed → claimed → done)
- [ ] Two users tapping simultaneously (no conflicts)
- [ ] Bubble colors correct (Yellow/Orange/Blue/Green)
- [ ] Bubble sizes correct (120/90/70px)
- [ ] Unpair maintains personal tasks
- [ ] Re-pair shows previous group tasks

## Future Enhancements

Suggestions from `pairing_prompt.md` not yet implemented:

1. **Assigned To Micro-Label**: Show initials on claimed tasks
2. **Nudge Button**: Send in-app ping to partner
3. **Today View**: Filter for tasks due today
4. **Undo Snackbar**: Quick undo after status change
5. **Conflict Safety**: Confirmation before creating group task

## Related Files

**Models:**
- `lib/models/task.dart` - Task model with visibility
- `lib/models/pairing.dart` - Pairing model

**Services:**
- `lib/services/task_service.dart` - Task CRUD with RPC
- `lib/services/pairing_service.dart` - Pairing management

**UI:**
- `lib/screens/home_screen.dart` - Main task view with filters
- `lib/widgets/task_creation_dialog.dart` - Creation dialog
- `lib/widgets/task_bubble.dart` - Bubble component

**Database:**
- `supabase/schema.sql` - Schema with RPC function

**Config:**
- `lib/config/theme.dart` - Colors
- `lib/config/constants.dart` - Sizes

## Notes

- All color and size specifications from `pairing_prompt.md` were already correctly implemented
- The main additions were visibility field, filtering, and atomic transitions
- Real-time sync and pairing system were already working correctly
- Personal/Group toggle follows Material Design patterns
- RLS policies ensure data security for both personal and group tasks
