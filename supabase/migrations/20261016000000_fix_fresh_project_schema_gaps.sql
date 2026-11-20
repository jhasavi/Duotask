-- ============================================================================
-- Fix two gaps that break a fresh Supabase project (staging, CI, local)
--
-- Both were found on 2026-10-16 by running the integration suite against a
-- local `supabase start` stack. The earlier chain check used stubbed auth
-- and never called the RPCs, so it couldn't see them. Both would have hit
-- the staging project in NEXT_STEPS.md Phase 0. Production was provisioned
-- by hand and bubble taps work there, so it must already have claimed_at.
-- Both statements are safe to run on it.
--
-- 1. tasks.claimed_at is missing from the baseline, but cycle_task_status
--    (every bubble tap) has always read and written it. On a fresh project
--    every tap failed with "column t.claimed_at does not exist".
--
-- 2. Sign-up fails. create_user_profile() runs from the on_auth_user_created
--    trigger, so it executes as supabase_auth_admin, whose search_path is
--    "auth". The baseline names its tables unqualified, so `users` resolved
--    to auth.users and every sign-up failed with "column display_name of
--    relation users does not exist" (the client sees "Database error
--    creating new user").
--
--    Same behavior as before; only the search_path is pinned and names are
--    schema-qualified.
-- ============================================================================

ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS claimed_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.create_user_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.users (id, email, display_name, pairing_code)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email),
    public.generate_pairing_code()
  );
  RETURN NEW;
END;
$$;
