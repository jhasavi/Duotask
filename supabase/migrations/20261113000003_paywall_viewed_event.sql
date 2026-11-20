-- ============================================================================
-- paywall_viewed usage event
--
-- The monetization funnel is signups -> paired -> paywall views -> paid.
-- Every step was in analytics.events except paywall views, which only a
-- client can observe.
--
-- analytics.log_event is closed to clients, so this adds a narrow RPC that
-- can log exactly one event type, for the caller only, with a fixed set of
-- props. Repeat views by the same user within a minute are dropped, so a
-- pull-to-refresh loop or a buggy client can't inflate the count.
-- ============================================================================

BEGIN;

ALTER TABLE analytics.events DROP CONSTRAINT IF EXISTS events_event_check;
ALTER TABLE analytics.events ADD CONSTRAINT events_event_check CHECK (event IN (
  'signup', 'pair_created', 'task_created', 'task_completed',
  'task_uncompleted', 'nudge_sent', 'premium_started', 'premium_ended',
  'share_created', 'share_opened', 'share_accepted', 'share_declined',
  'share_done', 'share_claimed',
  'paywall_viewed'
));

-- p_source: where the paywall was shown ('stats' today).
-- p_can_upgrade: false when the build has no Payment Link and the paywall
-- says "coming soon", so those views can be told apart.
CREATE OR REPLACE FUNCTION public.log_paywall_viewed(
  p_source TEXT,
  p_can_upgrade BOOLEAN DEFAULT TRUE
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  acting_user UUID := auth.uid();
  active_pair UUID;
BEGIN
  IF acting_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_source IS NULL OR p_source NOT IN ('stats', 'settings') THEN
    RAISE EXCEPTION 'invalid_source' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1 FROM analytics.events e
    WHERE e.user_id = acting_user
      AND e.event = 'paywall_viewed'
      AND e.created_at > now() - interval '1 minute'
  ) THEN
    RETURN;
  END IF;

  SELECT p.id INTO active_pair
  FROM public.pairings p
  WHERE p.status = 'active'
    AND (p.requester_id = acting_user OR p.recipient_id = acting_user)
  ORDER BY p.created_at DESC
  LIMIT 1;

  PERFORM analytics.log_event(
    'paywall_viewed',
    acting_user,
    active_pair,
    jsonb_build_object(
      'source', p_source,
      'can_upgrade', COALESCE(p_can_upgrade, TRUE)
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_paywall_viewed(TEXT, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_paywall_viewed(TEXT, BOOLEAN) TO authenticated;

COMMIT;
