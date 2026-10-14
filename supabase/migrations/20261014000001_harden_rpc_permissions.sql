-- ============================================================================
-- Harden SECURITY DEFINER RPCs
--
-- 1. cycle_task_status: stop trusting the client-supplied user_uuid.
--    The acting user is now auth.uid(). The user_uuid parameter is kept so the
--    signature (and the Flutter client call in lib/services/task_service.dart)
--    stays compatible, but a value that differs from auth.uid() is rejected.
--    The caller must also be allowed to act on the task, mirroring the tasks
--    UPDATE RLS policy: the creator, the assignee, or (for group tasks) a
--    member of the task's active pairing.
--    Requests made with the service_role key (no auth.uid()) may still act on
--    behalf of user_uuid, for trusted server-side tooling.
--
-- 2. get_daily_email_data / get_daily_email_tasks: only the daily-email-digest
--    Edge Function (which uses the service role key) calls these, so remove
--    access for PUBLIC, anon and authenticated.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.cycle_task_status(
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
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  acting_user UUID;
  current_status TEXT;
  current_visibility TEXT;
  current_claimed_by UUID;
  current_claimed_at TIMESTAMPTZ;
  current_created_by UUID;
  current_assigned_to UUID;
  current_pair_id UUID;
  new_status TEXT;
  new_claimed_by UUID;
  new_claimed_at TIMESTAMPTZ;
  new_completed_at TIMESTAMPTZ;
BEGIN
  acting_user := auth.uid();

  IF acting_user IS NULL THEN
    IF auth.role() = 'service_role' AND user_uuid IS NOT NULL THEN
      acting_user := user_uuid;
    ELSE
      RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;
  ELSIF user_uuid IS NOT NULL AND user_uuid <> acting_user THEN
    RAISE EXCEPTION 'user_uuid does not match the authenticated user'
      USING ERRCODE = '42501';
  END IF;

  -- Lock the row for update to prevent race conditions
  SELECT t.status, t.visibility, t.claimed_by_id, t.claimed_at,
         t.created_by_id, t.assigned_to_id, t.pair_id
  INTO current_status, current_visibility, current_claimed_by,
       current_claimed_at, current_created_by, current_assigned_to,
       current_pair_id
  FROM public.tasks t
  WHERE t.id = task_uuid
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Task not found' USING ERRCODE = 'P0002';
  END IF;

  -- Permission check: mirrors the tasks UPDATE RLS policy.
  IF NOT (
    current_created_by = acting_user
    OR current_assigned_to = acting_user
    OR (
      current_visibility = 'group'
      AND current_pair_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM public.pairings p
        WHERE p.id = current_pair_id
          AND p.status = 'active'
          AND (p.requester_id = acting_user OR p.recipient_id = acting_user)
      )
    )
  ) THEN
    RAISE EXCEPTION 'Not allowed to update this task' USING ERRCODE = '42501';
  END IF;

  -- Determine new status based on current status
  CASE current_status
    WHEN 'unclaimed' THEN
      new_status := 'claimed';
      new_claimed_by := acting_user;
      new_claimed_at := NOW();
      new_completed_at := NULL;
    WHEN 'claimed' THEN
      -- OWNERSHIP LOCK: For group tasks, only the claimer can complete
      IF current_visibility = 'group'
         AND current_claimed_by IS DISTINCT FROM acting_user THEN
        RAISE EXCEPTION 'Only the task owner can complete this task';
      END IF;

      new_status := 'completed';
      new_claimed_by := current_claimed_by;
      new_claimed_at := current_claimed_at;
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
  UPDATE public.tasks
  SET
    status = new_status,
    claimed_by_id = new_claimed_by,
    claimed_at = new_claimed_at,
    completed_at = new_completed_at,
    updated_at = NOW()
  WHERE public.tasks.id = task_uuid
  RETURNING public.tasks.id, public.tasks.status::TEXT,
            public.tasks.claimed_by_id, public.tasks.claimed_at,
            public.tasks.completed_at, public.tasks.updated_at;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cycle_task_status(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cycle_task_status(UUID, UUID) TO authenticated, service_role;

-- Daily email helpers: service role only.
REVOKE EXECUTE ON FUNCTION public.get_daily_email_data(UUID) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_daily_email_tasks(UUID) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_email_data(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_daily_email_tasks(UUID) TO service_role;

COMMIT;
