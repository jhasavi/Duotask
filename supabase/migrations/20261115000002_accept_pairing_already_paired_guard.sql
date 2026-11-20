-- ============================================================================
-- accept_pairing: refuse when either person is already paired
--
-- accept_pairing activated any pending code without checking whether the
-- joiner, or the person who made the code, already had an active pairing.
-- Typing a second code (or calling the RPC directly) left a user with two
-- active pairings, and users.paired_with_id pointing at whichever trigger
-- ran last. The invite-link flow checks first in the app, but the database
-- has to hold the rule.
--
-- New errors: 'already_paired' (the joiner) and 'inviter_paired' (the code's
-- owner paired with someone else after making it). Everything else is as in
-- 20261030000001_accept_pairing_rpc.sql. Same signature, so CREATE OR
-- REPLACE keeps the existing grants.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.accept_pairing(
  p_code TEXT,
  p_user_id UUID DEFAULT NULL
)
RETURNS public.pairings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  acting_user UUID;
  target public.pairings;
BEGIN
  acting_user := auth.uid();

  IF acting_user IS NULL THEN
    IF auth.role() = 'service_role' AND p_user_id IS NOT NULL THEN
      acting_user := p_user_id;
    ELSE
      RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;
  ELSIF p_user_id IS NOT NULL AND p_user_id <> acting_user THEN
    RAISE EXCEPTION 'p_user_id does not match the authenticated user'
      USING ERRCODE = '42501';
  END IF;

  -- Lock the row so two people can't join the same code at once.
  SELECT * INTO target
  FROM public.pairings
  WHERE pairing_code = upper(trim(p_code))
    AND status = 'pending'
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_code' USING ERRCODE = 'P0002';
  END IF;

  IF target.requester_id = acting_user THEN
    RAISE EXCEPTION 'own_code' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.pairings p
    WHERE p.status = 'active'
      AND (p.requester_id = acting_user OR p.recipient_id = acting_user)
  ) THEN
    RAISE EXCEPTION 'already_paired' USING ERRCODE = '23505';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.pairings p
    WHERE p.status = 'active'
      AND (p.requester_id = target.requester_id
           OR p.recipient_id = target.requester_id)
  ) THEN
    RAISE EXCEPTION 'inviter_paired' USING ERRCODE = '23505';
  END IF;

  UPDATE public.pairings
  SET recipient_id = acting_user,
      status = 'active',
      accepted_at = now()
  WHERE id = target.id
  RETURNING * INTO target;

  RETURN target;
END;
$$;

COMMIT;
