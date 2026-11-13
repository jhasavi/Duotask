-- ============================================================================
-- Account deletion
--
-- The privacy policy promises "Delete your entire account", and both app
-- stores require in-app account deletion, but nothing in the app did it.
--
-- Deleting the auth.users row cascades through public.users to tasks,
-- pairings, nudges, task_shares, device_tokens, email_preferences,
-- billing_customers and analytics.events (all ON DELETE CASCADE). The
-- partner's users.paired_with_id is ON DELETE SET NULL, so they are
-- unpaired, not deleted.
--
-- Shared tasks the partner created stay with the partner. Tasks the deleted
-- user created are removed with them (created_by_id cascades).
--
-- Two guards, both enforced here so a direct API call can't skip them:
--
--  1. Refuses while the user has a live subscription. The cascade removes
--     billing_customers, the only link between a Stripe customer and a user,
--     so deleting first would leave Stripe charging an account that no
--     longer exists. Error message: 'active_subscription'.
--  2. Users who have a password must supply it. A stolen or left-open
--     session token alone can't erase an account, matching password change.
--     Errors: 'password_required' / 'wrong_password'. Users with no password
--     (Google sign-in, magic link) have nothing to check.
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.delete_my_account(p_password TEXT DEFAULT NULL)
RETURNS void
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
    IF crypt(p_password, stored_hash) <> stored_hash THEN
      RAISE EXCEPTION 'wrong_password' USING ERRCODE = '28000';
    END IF;
  END IF;

  -- Unpair first so the partner's row is consistent even if a trigger
  -- reads it during the cascade.
  UPDATE public.users
  SET paired_with_id = NULL
  WHERE paired_with_id = acting_user;

  DELETE FROM auth.users WHERE id = acting_user;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.delete_my_account(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account(TEXT) TO authenticated;

COMMIT;
