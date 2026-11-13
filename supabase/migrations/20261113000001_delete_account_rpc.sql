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
-- Caveat: this does not cancel a Stripe subscription. The app warns the
-- user to cancel first (Settings > Manage subscription).
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  acting_user UUID := auth.uid();
BEGIN
  IF acting_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  -- Unpair first so the partner's row is consistent even if a trigger
  -- reads it during the cascade.
  UPDATE public.users
  SET paired_with_id = NULL
  WHERE paired_with_id = acting_user;

  DELETE FROM auth.users WHERE id = acting_user;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.delete_my_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;

COMMIT;
