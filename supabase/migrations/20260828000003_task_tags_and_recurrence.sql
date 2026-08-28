-- ============================================================================
-- DuoTask: Task tags and extended recurrence (monthly/yearly + end date)
-- ============================================================================

BEGIN;

-- 1. Tags
ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS tags TEXT[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_tasks_tags ON tasks USING GIN (tags);

-- 2. Recurrence end date
ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS recurrence_end_date TIMESTAMPTZ;

-- 3. Widen the recurrence CHECK constraint to allow monthly/yearly.
--    The baseline migration defines it inline as tasks_recurrence_check.
ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_recurrence_check;
ALTER TABLE tasks
  ADD CONSTRAINT tasks_recurrence_check
  CHECK (recurrence IN ('none', 'daily', 'weekly', 'monthly', 'yearly'));

COMMIT;
