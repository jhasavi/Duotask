-- ============================================================================
-- Fix: joining a partner's pairing code never paired anyone
--
-- PairingService.acceptPairingCode updated the pending row directly. The
-- pairings UPDATE policy only lets the requester or the recipient change a
-- row, and recipient_id is NULL until someone joins, so the joiner's UPDATE
-- matched zero rows. PostgREST returns that as an empty result, not an
-- error, and the app showed "Successfully paired!" while the row stayed
-- pending.
--
-- Found on 2026-10-30 in a browser test against a local stack. The
-- integration test passed because it ran both users as service_role, which
-- bypasses RLS.
--
-- accept_pairing does the join as one checked, atomic step. The UPDATE
-- policy is left as it is, so nobody can claim a pending row directly.
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

  UPDATE public.pairings
  SET recipient_id = acting_user,
      status = 'active',
      accepted_at = now()
  WHERE id = target.id
  RETURNING * INTO target;

  RETURN target;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.accept_pairing(TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_pairing(TEXT, UUID) TO authenticated, service_role;

COMMIT;
