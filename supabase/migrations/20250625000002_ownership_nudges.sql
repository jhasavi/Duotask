-- ============================================================================
-- DuoTask v1.1: Ownership Lock & Nudges Migration
-- Run this entire script in Supabase SQL Editor
-- ============================================================================

BEGIN;

-- 1. Update cycle_task_status RPC to enforce ownership lock for group tasks
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
  current_visibility TEXT;
  current_claimed_by UUID;
  new_status TEXT;
  new_claimed_by UUID;
  new_claimed_at TIMESTAMPTZ;
  new_completed_at TIMESTAMPTZ;
BEGIN
  -- Lock the row for update to prevent race conditions
  SELECT tasks.status, tasks.visibility, tasks.claimed_by_id 
  INTO current_status, current_visibility, current_claimed_by
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
      -- OWNERSHIP LOCK: For group tasks, only the claimer can complete
      IF current_visibility = 'group' AND current_claimed_by != user_uuid THEN
        RAISE EXCEPTION 'Only the task owner can complete this task';
      END IF;
      
      new_status := 'completed';
      new_claimed_by := current_claimed_by;
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

-- 2. Create nudges table for partner notifications
CREATE TABLE IF NOT EXISTS nudges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pair_id UUID NOT NULL REFERENCES pairings(id) ON DELETE CASCADE,
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  from_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Create indexes for nudges
CREATE INDEX IF NOT EXISTS idx_nudges_to_user ON nudges(to_user_id, read);
CREATE INDEX IF NOT EXISTS idx_nudges_pair ON nudges(pair_id);
CREATE INDEX IF NOT EXISTS idx_nudges_created ON nudges(created_at DESC);

-- 4. Enable RLS on nudges
ALTER TABLE nudges ENABLE ROW LEVEL SECURITY;

-- 5. Create RLS policies for nudges
DROP POLICY IF EXISTS "Users can view their received nudges" ON nudges;
CREATE POLICY "Users can view their received nudges"
  ON nudges FOR SELECT
  USING (auth.uid() = to_user_id);

DROP POLICY IF EXISTS "Users can insert nudges" ON nudges;
CREATE POLICY "Users can insert nudges"
  ON nudges FOR INSERT
  WITH CHECK (auth.uid() = from_user_id);

DROP POLICY IF EXISTS "Users can update their received nudges" ON nudges;
CREATE POLICY "Users can update their received nudges"
  ON nudges FOR UPDATE
  USING (auth.uid() = to_user_id);

-- 6. Success messages
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🎉 v1.1 Migration completed successfully!';
  RAISE NOTICE '';
  RAISE NOTICE '✅ Updated cycle_task_status with ownership lock';
  RAISE NOTICE '✅ Created nudges table and indexes';
  RAISE NOTICE '✅ Set up RLS policies for nudges';
  RAISE NOTICE '';
  RAISE NOTICE '🚀 Features enabled:';
  RAISE NOTICE '  - Ownership lock for group tasks';
  RAISE NOTICE '  - Partner nudge notifications';
END $$;

COMMIT;

-- ============================================================================
-- Migration Complete!
-- ============================================================================
