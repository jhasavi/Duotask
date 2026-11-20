-- ============================================================================
-- Throttle the password check in delete_my_account
--
-- ADR-001 finding 1: delete_my_account() compares p_password against
-- auth.users.encrypted_password with crypt(). Any valid session could call it
-- in a loop, which made it an unthrottled password oracle (GoTrue's own
-- sign-in rate limits don't apply to an RPC).
--
-- Fix: record each wrong password and refuse after 5 in 15 minutes.
--
-- A wrong password can no longer RAISE: the exception would roll back the
-- row that records the attempt. So the function now returns TEXT:
--   'deleted'         the account is gone
--   'wrong_password'  the attempt was recorded, nothing else changed
-- Everything that records nothing still raises, as before:
--   'Not authenticated', 'active_subscription', 'password_required',
--   'too_many_attempts' (new).
--
-- Forward-only: 20261113000001 is left as it was. Changing the return type
-- needs a DROP, so this file drops and recreates the function.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.account_deletion_attempts (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_account_deletion_attempts_user_time
  ON public.account_deletion_attempts (user_id, attempted_at);

-- Only the SECURITY DEFINER function below touches this table.
ALTER TABLE public.account_deletion_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.account_deletion_attempts FROM PUBLIC, anon, authenticated;

DROP FUNCTION IF EXISTS public.delete_my_account();
DROP FUNCTION IF EXISTS public.delete_my_account(TEXT);

CREATE FUNCTION public.delete_my_account(p_password TEXT DEFAULT NULL)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  acting_user UUID := auth.uid();
  stored_hash TEXT;
  premium_flag BOOLEAN;
  premium_end TIMESTAMPTZ;
  sub_status TEXT;
  recent_failures INT;
BEGIN
  IF acting_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  -- 1. Live subscription?
  SELECT u.is_premium, u.premium_until
    INTO premium_flag, premium_end
  FROM public.users u
  WHERE u.id = acting_user;

  SELECT b.subscription_status
    INTO sub_status
  FROM public.billing_customers b
  WHERE b.user_id = acting_user;

  IF (COALESCE(premium_flag, FALSE) AND (premium_end IS NULL OR premium_end > now()))
     OR sub_status IN ('active', 'trialing', 'past_due', 'unpaid') THEN
    RAISE EXCEPTION 'active_subscription' USING ERRCODE = 'P0001';
  END IF;

  -- 2. Password check, for accounts that have one.
  SELECT a.encrypted_password
    INTO stored_hash
  FROM auth.users a
  WHERE a.id = acting_user;

  IF stored_hash IS NOT NULL AND stored_hash <> '' THEN
    IF p_password IS NULL OR p_password = '' THEN
      RAISE EXCEPTION 'password_required' USING ERRCODE = '28000';
    END IF;

    -- Keep the table small: nothing older than the window matters.
    DELETE FROM public.account_deletion_attempts
    WHERE user_id = acting_user
      AND attempted_at < now() - interval '1 day';

    SELECT count(*)
      INTO recent_failures
    FROM public.account_deletion_attempts
    WHERE user_id = acting_user
      AND attempted_at > now() - interval '15 minutes';

    IF recent_failures >= 5 THEN
      RAISE EXCEPTION 'too_many_attempts' USING ERRCODE = '54000';
    END IF;

    IF crypt(p_password, stored_hash) <> stored_hash THEN
      INSERT INTO public.account_deletion_attempts (user_id)
      VALUES (acting_user);
      RETURN 'wrong_password';
    END IF;
  END IF;

  -- Unpair first so the partner's row is consistent even if a trigger
  -- reads it during the cascade.
  UPDATE public.users
  SET paired_with_id = NULL
  WHERE paired_with_id = acting_user;

  -- Cascades to account_deletion_attempts as well.
  DELETE FROM auth.users WHERE id = acting_user;
  RETURN 'deleted';
END;
$$;

REVOKE EXECUTE ON FUNCTION public.delete_my_account(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account(TEXT) TO authenticated;

COMMIT;
