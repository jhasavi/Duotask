-- ============================================================================
-- Pairings need both people's consent; nudges only go to your partner
--
-- Before this migration (see docs/adr/002-launch-readiness-review.md):
--
-- 1. SELECT on pairings allowed any row with status = 'pending', for anyone,
--    including the anon key. Every open pairing code and its owner's user id
--    could be listed, and any account could then accept_pairing a stranger's
--    code. Nothing reads pending rows by code any more: accept_pairing,
--    pair_invite_preview and claim_task_share are SECURITY DEFINER, and the
--    app only reads its own pending row.
--
-- 2. INSERT on pairings checked only requester_id = auth.uid(), so a client
--    could insert an 'active' pairing with any recipient. That skipped the
--    other person's consent and the already-paired guard, and it made the
--    caller "premium via partner" (get_premium_status) whenever the victim
--    paid. The app's "Re-pair" button used this path; it now sends a new
--    invite code instead.
--
-- 3. UPDATE on pairings let either party change any column, so a requester
--    could set recipient_id and status = 'active' on their own pending row.
--    The app only ever cancels a pairing from the client, so that is all a
--    client may do now. RPCs (owned by postgres) are unaffected.
--
-- 4. INSERT on nudges checked only from_user_id = auth.uid(); with the
--    send-nudge-push trigger that let anyone push to any user id.
-- ============================================================================

BEGIN;

-- 1. Read only the pairings you are part of.
DROP POLICY IF EXISTS "Users can view their pairings or search pending codes" ON public.pairings;
DROP POLICY IF EXISTS "Users can view pairings they're involved in" ON public.pairings;
CREATE POLICY "Users can view pairings they're involved in"
  ON public.pairings FOR SELECT
  TO authenticated
  USING (auth.uid() = requester_id OR auth.uid() = recipient_id);

-- 2. Clients may only open a pending invite of their own, addressed to no one.
DROP POLICY IF EXISTS "Users can create pairing requests" ON public.pairings;
CREATE POLICY "Users can create pairing requests"
  ON public.pairings FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = requester_id
    AND recipient_id IS NULL
    AND status = 'pending'
    AND accepted_at IS NULL
  );

-- 3. Clients may only cancel. The policy decides which rows; the trigger
--    decides which changes, since a policy cannot see OLD.
DROP POLICY IF EXISTS "Users can update pairings they're involved in" ON public.pairings;
CREATE POLICY "Users can update pairings they're involved in"
  ON public.pairings FOR UPDATE
  TO authenticated
  USING (auth.uid() = requester_id OR auth.uid() = recipient_id)
  WITH CHECK (auth.uid() = requester_id OR auth.uid() = recipient_id);

-- current_user, not auth.role(): inside a SECURITY DEFINER RPC the JWT role
-- is still 'authenticated' but current_user is the function owner, and the
-- RPCs (accept_pairing, claim_task_share) must keep activating pairings.
CREATE OR REPLACE FUNCTION public.guard_client_pairing_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  IF current_user IN ('anon', 'authenticated') THEN
    IF NEW.requester_id IS DISTINCT FROM OLD.requester_id
       OR NEW.recipient_id IS DISTINCT FROM OLD.recipient_id
       OR NEW.pairing_code IS DISTINCT FROM OLD.pairing_code
       OR NEW.accepted_at IS DISTINCT FROM OLD.accepted_at
       OR NEW.created_at IS DISTINCT FROM OLD.created_at
       OR (NEW.status IS DISTINCT FROM OLD.status AND NEW.status <> 'cancelled')
    THEN
      RAISE EXCEPTION 'Pairings can only be cancelled from the app'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_client_pairing_update ON public.pairings;
CREATE TRIGGER trg_guard_client_pairing_update
  BEFORE UPDATE ON public.pairings
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_client_pairing_update();

-- 4. Nudge only someone you are actively paired with.
DROP POLICY IF EXISTS "Users can insert nudges" ON public.nudges;
CREATE POLICY "Users can insert nudges"
  ON public.nudges FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = from_user_id
    AND EXISTS (
      SELECT 1 FROM public.pairings p
      WHERE p.status = 'active'
        AND (
          (p.requester_id = from_user_id AND p.recipient_id = to_user_id)
          OR (p.recipient_id = from_user_id AND p.requester_id = to_user_id)
        )
    )
  );

COMMIT;
