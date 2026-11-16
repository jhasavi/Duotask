-- ============================================================================
-- Partner invite links
--
-- Pairing meant reading an 8-character code out loud. Now the code goes out
-- as a link, https://<app>/?pair=<CODE>, sent from the inviter's own phone
-- (WhatsApp, text, email, copy). The app keeps the code through sign-up and
-- pairs automatically with the existing accept_pairing RPC.
--
-- This migration adds what the server side needs:
--
--   pair_invite_preview(code)    anon-callable. The inviter's first name for
--                                the "Sam invited you" banner, or NULL. Logs
--                                pair_invite_opened once per pairing.
--   log_pair_invite_sent(chan)   authenticated. Logs pair_invite_sent.
--
-- Funnel: pair_invite_sent -> pair_invite_opened -> pair_created.
-- ============================================================================

BEGIN;

ALTER TABLE analytics.events DROP CONSTRAINT IF EXISTS events_event_check;
ALTER TABLE analytics.events ADD CONSTRAINT events_event_check CHECK (event IN (
  'signup', 'pair_created', 'task_created', 'task_completed',
  'task_uncompleted', 'nudge_sent', 'premium_started', 'premium_ended',
  'share_created', 'share_opened', 'share_accepted', 'share_declined',
  'share_done', 'share_claimed',
  'paywall_viewed',
  'pair_invite_sent', 'pair_invite_opened'
));

-- Only the first name, and only for a code that is still pending, so a
-- guessed code reveals as little as possible. Codes are 8 characters from
-- 36, so guessing one is impractical anyway.
CREATE OR REPLACE FUNCTION public.pair_invite_preview(p_code TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target public.pairings;
  inviter_name TEXT;
BEGIN
  IF p_code IS NULL OR upper(trim(p_code)) !~ '^[A-Z0-9]{6,12}$' THEN
    RETURN NULL;
  END IF;

  SELECT * INTO target
  FROM public.pairings
  WHERE pairing_code = upper(trim(p_code))
    AND status = 'pending'
  ORDER BY created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT NULLIF(split_part(trim(u.display_name), ' ', 1), '')
    INTO inviter_name
  FROM public.users u
  WHERE u.id = target.requester_id;

  IF NOT EXISTS (
    SELECT 1 FROM analytics.events e
    WHERE e.event = 'pair_invite_opened' AND e.pair_id = target.id
  ) THEN
    PERFORM analytics.log_event(
      'pair_invite_opened', target.requester_id, target.id, '{}'::jsonb
    );
  END IF;

  -- Empty string, not NULL, when the code is valid but the inviter has no
  -- name, so the app can still say "You've been invited".
  RETURN COALESCE(inviter_name, '');
END;
$$;

REVOKE ALL ON FUNCTION public.pair_invite_preview(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pair_invite_preview(TEXT) TO anon, authenticated;

-- p_channel: how the link left the inviter's phone.
CREATE OR REPLACE FUNCTION public.log_pair_invite_sent(p_channel TEXT)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  acting_user UUID := auth.uid();
  pending_pair UUID;
BEGIN
  IF acting_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_channel IS NULL
     OR p_channel NOT IN ('whatsapp', 'text', 'email', 'copy') THEN
    RAISE EXCEPTION 'invalid_channel' USING ERRCODE = '22023';
  END IF;

  -- Same channel twice within a minute is one send (double taps, retries).
  IF EXISTS (
    SELECT 1 FROM analytics.events e
    WHERE e.user_id = acting_user
      AND e.event = 'pair_invite_sent'
      AND e.props->>'channel' = p_channel
      AND e.created_at > now() - interval '1 minute'
  ) THEN
    RETURN;
  END IF;

  SELECT p.id INTO pending_pair
  FROM public.pairings p
  WHERE p.requester_id = acting_user
    AND p.status = 'pending'
  ORDER BY p.created_at DESC
  LIMIT 1;

  PERFORM analytics.log_event(
    'pair_invite_sent',
    acting_user,
    pending_pair,
    jsonb_build_object('channel', p_channel)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.log_pair_invite_sent(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_pair_invite_sent(TEXT) TO authenticated;

COMMIT;
