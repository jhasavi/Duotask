-- ============================================================================
-- Privacy-friendly usage analytics
--
-- Purpose: measure activation and retention without a third-party tracker.
--
-- Events are written by database triggers, not by the Flutter client, so:
--   * they can't be skipped by an old client or forged from the console;
--   * no tracking SDK, cookie or device fingerprint is involved;
--   * only IDs, an event name and a few non-content properties are stored —
--     never task titles, descriptions, nudge messages or email addresses.
--
-- The table lives in a separate `analytics` schema that PostgREST does not
-- expose (supabase/config.toml exposes only public and graphql_public), and
-- anon/authenticated have no privileges on it. Read it from the SQL editor;
-- example queries are in docs/MONETIZATION.md#measuring-usage.
--
-- Events are deleted with the user (ON DELETE CASCADE).
--
-- Events:
--   signup            a users row is created
--   pair_created      a pairing becomes active
--   task_created      a task row is inserted (includes the next occurrence
--                     auto-created when a recurring task is completed;
--                     props.recurrence lets you filter those out)
--   task_completed    a task's status changes to completed
--   task_uncompleted  a completion is undone
--   nudge_sent        a nudge row is inserted
--   premium_started   users.is_premium goes false -> true
--   premium_ended     users.is_premium goes true -> false
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS analytics;
REVOKE ALL ON SCHEMA analytics FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS analytics.events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event TEXT NOT NULL CHECK (event IN (
    'signup', 'pair_created', 'task_created', 'task_completed',
    'task_uncompleted', 'nudge_sent', 'premium_started', 'premium_ended'
  )),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  pair_id UUID,
  props JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_events_event_time
  ON analytics.events (event, created_at);
CREATE INDEX IF NOT EXISTS idx_events_user_time
  ON analytics.events (user_id, created_at);

ALTER TABLE analytics.events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON analytics.events FROM PUBLIC, anon, authenticated;

-- Never let analytics break the write it observes.
CREATE OR REPLACE FUNCTION analytics.log_event(
  p_event TEXT,
  p_user_id UUID,
  p_pair_id UUID DEFAULT NULL,
  p_props JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = analytics, pg_temp
AS $$
BEGIN
  INSERT INTO analytics.events (event, user_id, pair_id, props)
  VALUES (p_event, p_user_id, p_pair_id, COALESCE(p_props, '{}'::jsonb));
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'analytics.log_event(%) failed: %', p_event, SQLERRM;
END;
$$;

REVOKE ALL ON FUNCTION analytics.log_event(TEXT, UUID, UUID, JSONB)
  FROM PUBLIC, anon, authenticated;

-- signup ----------------------------------------------------------------------
CREATE OR REPLACE FUNCTION analytics.on_user_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = analytics, pg_temp
AS $$
BEGIN
  PERFORM analytics.log_event('signup', NEW.id);
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_analytics_signup ON public.users;
CREATE TRIGGER trg_analytics_signup
  AFTER INSERT ON public.users
  FOR EACH ROW EXECUTE FUNCTION analytics.on_user_insert();

-- premium_started / premium_ended ---------------------------------------------
CREATE OR REPLACE FUNCTION analytics.on_user_premium_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = analytics, pg_temp
AS $$
BEGIN
  IF NEW.is_premium AND NOT OLD.is_premium THEN
    PERFORM analytics.log_event('premium_started', NEW.id);
  ELSIF OLD.is_premium AND NOT NEW.is_premium THEN
    PERFORM analytics.log_event('premium_ended', NEW.id);
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_analytics_premium ON public.users;
CREATE TRIGGER trg_analytics_premium
  AFTER UPDATE OF is_premium ON public.users
  FOR EACH ROW EXECUTE FUNCTION analytics.on_user_premium_change();

-- pair_created ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION analytics.on_pairing_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = analytics, pg_temp
AS $$
BEGIN
  IF NEW.status = 'active'
     AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'active') THEN
    -- Attributed to the person who completed the pairing.
    PERFORM analytics.log_event(
      'pair_created',
      COALESCE(NEW.recipient_id, NEW.requester_id),
      NEW.id,
      jsonb_build_object('repair', TG_OP = 'INSERT')
    );
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_analytics_pairing ON public.pairings;
CREATE TRIGGER trg_analytics_pairing
  AFTER INSERT OR UPDATE OF status ON public.pairings
  FOR EACH ROW EXECUTE FUNCTION analytics.on_pairing_change();

-- task_created / task_completed / task_uncompleted ----------------------------
CREATE OR REPLACE FUNCTION analytics.on_task_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = analytics, pg_temp
AS $$
DECLARE
  actor UUID := COALESCE(auth.uid(), NEW.claimed_by_id, NEW.created_by_id);
  props JSONB := jsonb_build_object(
    'visibility', NEW.visibility,
    'recurrence', NEW.recurrence,
    'priority', NEW.priority
  );
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM analytics.log_event('task_created', NEW.created_by_id, NEW.pair_id, props);
  ELSIF NEW.status = 'completed' AND OLD.status IS DISTINCT FROM 'completed' THEN
    PERFORM analytics.log_event('task_completed', actor, NEW.pair_id, props);
  ELSIF OLD.status = 'completed' AND NEW.status IS DISTINCT FROM 'completed' THEN
    PERFORM analytics.log_event('task_uncompleted', actor, NEW.pair_id, props);
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_analytics_task ON public.tasks;
CREATE TRIGGER trg_analytics_task
  AFTER INSERT OR UPDATE OF status ON public.tasks
  FOR EACH ROW EXECUTE FUNCTION analytics.on_task_change();

-- nudge_sent ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION analytics.on_nudge_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = analytics, pg_temp
AS $$
BEGIN
  PERFORM analytics.log_event('nudge_sent', NEW.from_user_id, NEW.pair_id);
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_analytics_nudge ON public.nudges;
CREATE TRIGGER trg_analytics_nudge
  AFTER INSERT ON public.nudges
  FOR EACH ROW EXECUTE FUNCTION analytics.on_nudge_insert();

-- Backfill what can be reconstructed from existing rows, so the first
-- dashboards aren't empty. Only runs once (when the table is empty).
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM analytics.events) THEN
    INSERT INTO analytics.events (event, user_id, created_at, props)
    SELECT 'signup', id, COALESCE(created_at, NOW()), '{"backfill": true}'
    FROM public.users;

    INSERT INTO analytics.events (event, user_id, pair_id, created_at, props)
    SELECT 'pair_created', COALESCE(recipient_id, requester_id), id,
           COALESCE(accepted_at, created_at, NOW()), '{"backfill": true}'
    FROM public.pairings
    WHERE status = 'active';

    INSERT INTO analytics.events (event, user_id, pair_id, created_at, props)
    SELECT 'task_created', created_by_id, pair_id, COALESCE(created_at, NOW()),
           jsonb_build_object('backfill', true, 'visibility', visibility,
                              'recurrence', recurrence, 'priority', priority)
    FROM public.tasks;

    INSERT INTO analytics.events (event, user_id, pair_id, created_at, props)
    SELECT 'task_completed', COALESCE(claimed_by_id, created_by_id), pair_id,
           completed_at,
           jsonb_build_object('backfill', true, 'visibility', visibility,
                              'recurrence', recurrence, 'priority', priority)
    FROM public.tasks
    WHERE status = 'completed' AND completed_at IS NOT NULL;

    INSERT INTO analytics.events (event, user_id, pair_id, created_at, props)
    SELECT 'nudge_sent', from_user_id, pair_id, COALESCE(created_at, NOW()),
           '{"backfill": true}'
    FROM public.nudges;
  END IF;
END;
$$;

COMMIT;
