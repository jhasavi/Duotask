-- ============================================================================
-- DuoTask: Pairing Improvements Migration
-- Run this entire script in Supabase SQL Editor
-- ============================================================================

BEGIN;

-- 1. Add visibility column to tasks table
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tasks' AND column_name = 'visibility'
  ) THEN
    ALTER TABLE tasks 
    ADD COLUMN visibility TEXT NOT NULL DEFAULT 'personal' 
    CHECK (visibility IN ('personal', 'group'));
    
    RAISE NOTICE '✅ Added visibility column';
  ELSE
    RAISE NOTICE '⏭️  visibility column already exists';
  END IF;
END $$;

-- 2. Add pair_id column to tasks table
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'tasks' AND column_name = 'pair_id'
  ) THEN
    ALTER TABLE tasks 
    ADD COLUMN pair_id UUID 
    REFERENCES pairings(id) ON DELETE SET NULL;
    
    RAISE NOTICE '✅ Added pair_id column';
  ELSE
    RAISE NOTICE '⏭️  pair_id column already exists';
  END IF;
END $$;

-- 3. Create indexes for performance
DO $$
BEGIN
  CREATE INDEX IF NOT EXISTS idx_tasks_pair_id ON tasks(pair_id);
  CREATE INDEX IF NOT EXISTS idx_tasks_visibility ON tasks(visibility);
  RAISE NOTICE '✅ Created indexes';
END $$;

-- 4. Migrate existing data
DO $$
BEGIN
  UPDATE tasks 
  SET visibility = CASE 
    WHEN is_personal = true THEN 'personal' 
    ELSE 'group' 
  END
  WHERE visibility = 'personal';
  RAISE NOTICE '✅ Migrated existing data';
END $$;

-- 5. Update RLS policies for tasks
DO $$
BEGIN
  DROP POLICY IF EXISTS "Users can view their own tasks" ON tasks;
  CREATE POLICY "Users can view their own tasks"
    ON tasks FOR SELECT
    USING (
      -- Personal tasks: only creator can see
      (visibility = 'personal' AND auth.uid() = created_by_id)
      OR
      -- Group tasks: both users in the pair can see
      (visibility = 'group' AND pair_id IN (
        SELECT id FROM pairings 
        WHERE status = 'active' 
        AND (requester_id = auth.uid() OR recipient_id = auth.uid())
      ))
      OR
      -- Backward compatibility
      auth.uid() = assigned_to_id OR
      auth.uid() = claimed_by_id
    );
  RAISE NOTICE '✅ Updated SELECT policy';
END $$;

DO $$
BEGIN
  DROP POLICY IF EXISTS "Users can update their own tasks" ON tasks;
  CREATE POLICY "Users can update their own tasks"
    ON tasks FOR UPDATE
    USING (
      -- Personal tasks: only creator can update
      (visibility = 'personal' AND auth.uid() = created_by_id)
      OR
      -- Group tasks: both users in the pair can update
      (visibility = 'group' AND pair_id IN (
        SELECT id FROM pairings 
        WHERE status = 'active' 
        AND (requester_id = auth.uid() OR recipient_id = auth.uid())
      ))
      OR
      -- Backward compatibility
      auth.uid() = assigned_to_id
    );
  RAISE NOTICE '✅ Updated UPDATE policy';
END $$;

-- 6. Create RPC function for atomic task status cycling
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
  -- Lock the row for update to prevent race conditions
  SELECT tasks.status INTO current_status
  FROM tasks
  WHERE tasks.id = task_uuid
  FOR UPDATE;

  -- Determine new status based on current status
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

  -- Update and return the task
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

-- 7. Success messages
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🎉 Migration completed successfully!';
  RAISE NOTICE '';
  RAISE NOTICE '📋 Verify the changes:';
  RAISE NOTICE '  SELECT column_name, data_type FROM information_schema.columns WHERE table_name = ''tasks'';';
  RAISE NOTICE '';
  RAISE NOTICE '🚀 Next steps:';
  RAISE NOTICE '  1. Run: flutter pub get';
  RAISE NOTICE '  2. Run: flutter run';
  RAISE NOTICE '  3. Test the new features';
END $$;

COMMIT;

-- ============================================================================
-- Migration Complete!
-- ============================================================================
