-- ============================================================================
-- Task share links: send a task to someone who doesn't have DuoTask
--
-- DuoTask only works once both people have signed up and paired, so every
-- new user first has to talk someone into installing an app. A share link
-- removes that step: the sender messages a link (from their own phone, via
-- WhatsApp, text or anything else), and the recipient opens a lightweight
-- page at /t/<token> where they can say "I'll do it", "Done" or "Can't" with
-- no account. The page then invites them to create a free account; claiming
-- the link pairs them with the sender when neither is paired yet.
--
-- Design notes:
--   * The token is the only credential: 18 random bytes (144 bits), URL-safe.
--     Links expire after 30 days and the sender can revoke them.
--   * Only personal, non-recurring tasks created by the caller can be shared.
--     Group tasks have an ownership lock (only the claimer may complete) that
--     a guest without an account can't satisfy, and the next occurrence of a
--     recurring task is created by the app, which a guest isn't running.
--   * Anonymous callers can only reach the task through two RPCs that take
--     the token. They see the title, notes, due date, priority and status,
--     plus the sender's display name when it isn't an email address.
--   * Opening the page reads state; nothing changes until a button is
--     pressed. That keeps link-preview bots (WhatsApp, iMessage, Slack),
--     which fetch the URL but run no JavaScript, from acting on a task.
--   * A guest's claim sets the task to claimed with claimed_by_id NULL; the
--     owner's app shows who via the share row (task_shares is in the
--     realtime publication so the sender sees responses live).
-- ============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS public.task_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  token TEXT NOT NULL UNIQUE DEFAULT translate(
    encode(extensions.gen_random_bytes(18), 'base64'), '+/', '-_'),
  task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  created_by_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  recipient_name TEXT CHECK (char_length(recipient_name) BETWEEN 1 AND 40),
  response TEXT NOT NULL DEFAULT 'pending'
    CHECK (response IN ('pending', 'accepted', 'declined', 'done')),
  responded_at TIMESTAMPTZ,
  first_opened_at TIMESTAMPTZ,
  open_count INTEGER NOT NULL DEFAULT 0,
  claimed_by_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  claimed_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '30 days',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- At most one live link per task, so re-sharing returns the same URL.
CREATE UNIQUE INDEX IF NOT EXISTS idx_task_shares_one_live_per_task
  ON public.task_shares (task_id) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_task_shares_created_by
  ON public.task_shares (created_by_id);

DROP TRIGGER IF EXISTS update_task_shares_updated_at ON public.task_shares;
CREATE TRIGGER update_task_shares_updated_at
  BEFORE UPDATE ON public.task_shares
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Reads only; every write goes through the RPCs below.
ALTER TABLE public.task_shares ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.task_shares FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.task_shares TO authenticated;

DROP POLICY IF EXISTS "Senders and claimers can view task shares" ON public.task_shares;
CREATE POLICY "Senders and claimers can view task shares"
  ON public.task_shares FOR SELECT
  TO authenticated
  USING (auth.uid() = created_by_id OR auth.uid() = claimed_by_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public'
      AND tablename = 'task_shares'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.task_shares;
  END IF;
END $$;

-- Analytics: allow the share funnel events.
ALTER TABLE analytics.events DROP CONSTRAINT IF EXISTS events_event_check;
ALTER TABLE analytics.events ADD CONSTRAINT events_event_check CHECK (event IN (
  'signup', 'pair_created', 'task_created', 'task_completed',
  'task_uncompleted', 'nudge_sent', 'premium_started', 'premium_ended',
  'share_created', 'share_opened', 'share_accepted', 'share_declined',
  'share_done', 'share_claimed'
));

-- Internal: the live share for a token, locked, or an error the page can show.
CREATE OR REPLACE FUNCTION public._live_task_share(p_token TEXT)
RETURNS public.task_shares
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  s public.task_shares;
BEGIN
  IF p_token IS NULL OR p_token !~ '^[A-Za-z0-9_-]{16,64}$' THEN
    RAISE EXCEPTION 'link_not_found' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO s FROM public.task_shares WHERE token = p_token FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'link_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF s.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'link_revoked' USING ERRCODE = 'P0001';
  END IF;
  IF s.expires_at < NOW() THEN
    RAISE EXCEPTION 'link_expired' USING ERRCODE = 'P0001';
  END IF;
  RETURN s;
END;
$$;

REVOKE ALL ON FUNCTION public._live_task_share(TEXT) FROM PUBLIC, anon, authenticated;

-- Internal: what the recipient's page shows. Never includes emails or IDs
-- other than the token the caller already has.
CREATE OR REPLACE FUNCTION public._task_share_view(s public.task_shares)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'title', t.title,
    'description', t.description,
    'due_date', t.due_date,
    'priority', t.priority,
    'task_status', t.status,
    'response', s.response,
    'responded_at', s.responded_at,
    'recipient_name', s.recipient_name,
    'sender_name', CASE
      WHEN u.display_name IS NULL OR u.display_name LIKE '%@%' THEN NULL
      ELSE left(u.display_name, 40)
    END,
    'claimed', s.claimed_by_id IS NOT NULL,
    'expires_at', s.expires_at
  )
  FROM public.tasks t
  JOIN public.users u ON u.id = s.created_by_id
  WHERE t.id = s.task_id;
$$;

REVOKE ALL ON FUNCTION public._task_share_view(public.task_shares) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- create_task_share: the sender gets (or reuses) the link for one of their
-- tasks. Returns the share row; the app builds the URL from its token.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_task_share(
  p_task_id UUID,
  p_recipient_name TEXT DEFAULT NULL
)
RETURNS public.task_shares
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  me UUID := auth.uid();
  t public.tasks;
  s public.task_shares;
  v_name TEXT := NULLIF(left(btrim(p_recipient_name), 40), '');
  have_live BOOLEAN;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO t FROM public.tasks WHERE id = p_task_id FOR UPDATE;
  IF NOT FOUND OR t.created_by_id <> me THEN
    RAISE EXCEPTION 'You can only share your own tasks' USING ERRCODE = '42501';
  END IF;
  IF t.visibility <> 'personal' THEN
    RAISE EXCEPTION 'Only personal tasks can be sent by link' USING ERRCODE = 'P0001';
  END IF;
  IF t.recurrence <> 'none' THEN
    RAISE EXCEPTION 'Repeating tasks can''t be sent by link yet' USING ERRCODE = 'P0001';
  END IF;
  IF t.status = 'completed' THEN
    RAISE EXCEPTION 'This task is already done' USING ERRCODE = 'P0001';
  END IF;

  -- Reuse the live link, retiring one that has expired.
  SELECT * INTO s FROM public.task_shares
  WHERE task_id = p_task_id AND revoked_at IS NULL
  FOR UPDATE;
  have_live := FOUND;

  IF have_live AND s.expires_at < NOW() THEN
    UPDATE public.task_shares SET revoked_at = NOW() WHERE id = s.id;
    have_live := FALSE;
  END IF;

  IF have_live THEN
    IF v_name IS NOT NULL AND v_name IS DISTINCT FROM s.recipient_name THEN
      UPDATE public.task_shares SET recipient_name = v_name
      WHERE id = s.id RETURNING * INTO s;
    END IF;
    RETURN s;
  END IF;

  INSERT INTO public.task_shares (task_id, created_by_id, recipient_name)
  VALUES (p_task_id, me, v_name)
  RETURNING * INTO s;

  PERFORM analytics.log_event('share_created', me, NULL, '{}'::jsonb);
  RETURN s;
END;
$$;

REVOKE ALL ON FUNCTION public.create_task_share(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_task_share(UUID, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- revoke_task_share: the sender stops sharing. The old link stops working;
-- a later share creates a new one.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.revoke_task_share(p_task_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  me UUID := auth.uid();
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  UPDATE public.task_shares
  SET revoked_at = NOW()
  WHERE task_id = p_task_id AND created_by_id = me AND revoked_at IS NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.revoke_task_share(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.revoke_task_share(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- get_shared_task: what the /t/<token> page shows. Open to anon.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_shared_task(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  s public.task_shares := public._live_task_share(p_token);
BEGIN
  IF s.first_opened_at IS NULL THEN
    PERFORM analytics.log_event('share_opened', s.created_by_id, NULL, '{}'::jsonb);
  END IF;

  UPDATE public.task_shares
  SET open_count = open_count + 1,
      first_opened_at = COALESCE(first_opened_at, NOW())
  WHERE id = s.id
  RETURNING * INTO s;

  RETURN public._task_share_view(s);
END;
$$;

REVOKE ALL ON FUNCTION public.get_shared_task(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_shared_task(TEXT) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- respond_to_shared_task: the recipient's buttons. Open to anon.
--   accept  -> "I'll do it": task becomes claimed
--   done    -> task becomes completed
--   decline -> "Can't do it": task goes back to unclaimed if this link
--              had claimed it
--   undo    -> takes back "done": task goes back to claimed
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.respond_to_shared_task(
  p_token TEXT,
  p_action TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  s public.task_shares := public._live_task_share(p_token);
  t public.tasks;
  new_response TEXT;
BEGIN
  IF p_action NOT IN ('accept', 'done', 'decline', 'undo') THEN
    RAISE EXCEPTION 'Unknown action' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO t FROM public.tasks WHERE id = s.task_id FOR UPDATE;

  -- The sender may have finished it themselves. Only "undo" of the link's
  -- own completion can reopen a completed task.
  IF t.status = 'completed'
     AND NOT (p_action = 'undo' AND s.response = 'done') THEN
    RETURN public._task_share_view(s);
  END IF;

  CASE p_action
    WHEN 'accept' THEN
      new_response := 'accepted';
      IF t.status = 'unclaimed' THEN
        UPDATE public.tasks
        SET status = 'claimed', claimed_by_id = NULL, claimed_at = NOW()
        WHERE id = t.id;
      END IF;
    WHEN 'done' THEN
      new_response := 'done';
      UPDATE public.tasks
      SET status = 'completed',
          claimed_at = COALESCE(claimed_at, NOW()),
          completed_at = NOW()
      WHERE id = t.id;
    WHEN 'decline' THEN
      new_response := 'declined';
      IF t.status = 'claimed' AND t.claimed_by_id IS NULL
         AND s.response = 'accepted' THEN
        UPDATE public.tasks
        SET status = 'unclaimed', claimed_at = NULL
        WHERE id = t.id;
      END IF;
    WHEN 'undo' THEN
      IF s.response <> 'done' THEN
        RETURN public._task_share_view(s);
      END IF;
      new_response := 'accepted';
      UPDATE public.tasks
      SET status = 'claimed', completed_at = NULL
      WHERE id = t.id;
  END CASE;

  UPDATE public.task_shares
  SET response = new_response, responded_at = NOW()
  WHERE id = s.id
  RETURNING * INTO s;

  IF p_action <> 'undo' THEN
    PERFORM analytics.log_event('share_' || new_response, s.created_by_id,
                                NULL, '{}'::jsonb);
  END IF;

  RETURN public._task_share_view(s);
END;
$$;

REVOKE ALL ON FUNCTION public.respond_to_shared_task(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.respond_to_shared_task(TEXT, TEXT) TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- claim_task_share: the recipient has signed up (or signed in) from the
-- link. Their account takes over the task, and when neither person is
-- paired yet, the two are paired and the task becomes a shared one.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.claim_task_share(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  me UUID := auth.uid();
  s public.task_shares;
  t public.tasks;
  pairing_id UUID;
  sender_name TEXT;
  sender_paired BOOLEAN;
  me_paired BOOLEAN;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  s := public._live_task_share(p_token);

  IF s.created_by_id = me THEN
    RAISE EXCEPTION 'own_link' USING ERRCODE = 'P0001';
  END IF;
  IF s.claimed_by_id IS NOT NULL AND s.claimed_by_id <> me THEN
    RAISE EXCEPTION 'already_claimed' USING ERRCODE = 'P0001';
  END IF;

  SELECT CASE WHEN display_name LIKE '%@%' THEN NULL ELSE display_name END
  INTO sender_name FROM public.users WHERE id = s.created_by_id;

  -- Already claimed by me: report the current state without re-pairing.
  IF s.claimed_by_id = me THEN
    RETURN jsonb_build_object(
      'paired', EXISTS (
        SELECT 1 FROM public.pairings p
        WHERE p.status = 'active'
          AND ((p.requester_id = me AND p.recipient_id = s.created_by_id)
            OR (p.recipient_id = me AND p.requester_id = s.created_by_id))),
      'sender_name', sender_name,
      'task_id', s.task_id
    );
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.pairings p
    WHERE p.status = 'active'
      AND (p.requester_id = s.created_by_id OR p.recipient_id = s.created_by_id)
  ) INTO sender_paired;
  SELECT EXISTS (
    SELECT 1 FROM public.pairings p
    WHERE p.status = 'active' AND (p.requester_id = me OR p.recipient_id = me)
  ) INTO me_paired;

  IF NOT sender_paired AND NOT me_paired THEN
    -- Insert pending, then activate, so sync_pairing_status (BEFORE UPDATE)
    -- fills users.paired_with_* exactly as the pairing-code flow does.
    INSERT INTO public.pairings (requester_id, recipient_id, pairing_code, status)
    VALUES (s.created_by_id, me, public.generate_pairing_code(), 'pending')
    RETURNING id INTO pairing_id;

    UPDATE public.pairings SET status = 'active' WHERE id = pairing_id;

    -- Close out any stale pending codes either person had open.
    UPDATE public.pairings SET status = 'cancelled'
    WHERE status = 'pending' AND id <> pairing_id
      AND (requester_id IN (me, s.created_by_id));
  END IF;

  SELECT * INTO t FROM public.tasks WHERE id = s.task_id FOR UPDATE;

  UPDATE public.tasks
  SET assigned_to_id = me,
      claimed_by_id = CASE WHEN t.status <> 'unclaimed' AND t.claimed_by_id IS NULL
                           THEN me ELSE t.claimed_by_id END,
      visibility = CASE WHEN pairing_id IS NOT NULL THEN 'group' ELSE t.visibility END,
      is_personal = CASE WHEN pairing_id IS NOT NULL THEN FALSE ELSE t.is_personal END,
      pair_id = COALESCE(pairing_id, t.pair_id)
  WHERE id = t.id;

  UPDATE public.task_shares
  SET claimed_by_id = me, claimed_at = NOW()
  WHERE id = s.id;

  PERFORM analytics.log_event('share_claimed', me, pairing_id,
    jsonb_build_object('paired', pairing_id IS NOT NULL));

  RETURN jsonb_build_object(
    'paired', pairing_id IS NOT NULL,
    'sender_name', sender_name,
    'task_id', s.task_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.claim_task_share(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_task_share(TEXT) TO authenticated;

COMMIT;
