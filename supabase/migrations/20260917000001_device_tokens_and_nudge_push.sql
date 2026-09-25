-- ============================================================================
-- DuoTask: Push notifications for nudges
-- ============================================================================
-- Nudges today only reach a recipient who has the app open and subscribed to
-- Supabase Realtime (see NudgeService._setupRealtimeSubscription). This adds:
--
--   1. device_tokens — one row per (user, device) FCM registration token.
--   2. A trigger that fires on every `nudges` INSERT and calls the
--      `send-nudge-push` edge function, which delivers an FCM push to every
--      token the recipient has registered.
--
-- Reuses the `project_url` / `anon_key` Vault secrets already set up for the
-- daily email cron (20250625000005_setup_email_cron.sql). The edge function
-- itself additionally needs a `FIREBASE_SERVICE_ACCOUNT` function secret (via
-- `supabase secrets set`, like RESEND_API_KEY for the email digest) — see
-- docs/PUSH_NOTIFICATIONS_SETUP.md.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);

ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage their own device tokens" ON device_tokens;
CREATE POLICY "Users manage their own device tokens"
  ON device_tokens FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

COMMIT;

-- ----------------------------------------------------------------------------
-- Trigger: notify send-nudge-push on every new nudge
-- ----------------------------------------------------------------------------
-- Kept outside the transaction above so a missing pg_net/vault extension (both
-- already required by the email cron migration, so normally present) doesn't
-- roll back the device_tokens table itself.

CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS supabase_vault;

CREATE OR REPLACE FUNCTION notify_nudge_push()
RETURNS TRIGGER AS $$
DECLARE
  project_url TEXT;
  anon_key TEXT;
BEGIN
  SELECT decrypted_secret INTO project_url
    FROM vault.decrypted_secrets WHERE name = 'project_url';
  SELECT decrypted_secret INTO anon_key
    FROM vault.decrypted_secrets WHERE name = 'anon_key';

  -- Vault secrets aren't configured yet in every environment (e.g. local dev,
  -- or before the one-time setup in docs/RELEASE.md runs) — skip rather than
  -- fail the nudge insert itself.
  IF project_url IS NULL OR anon_key IS NULL THEN
    RETURN NEW;
  END IF;

  PERFORM net.http_post(
    url := project_url || '/functions/v1/send-nudge-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || anon_key
    ),
    body := jsonb_build_object('nudge_id', NEW.id)
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_notify_nudge_push ON nudges;
CREATE TRIGGER trg_notify_nudge_push
  AFTER INSERT ON nudges
  FOR EACH ROW
  EXECUTE FUNCTION notify_nudge_push();

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ device_tokens table created.';
  RAISE NOTICE '✅ Nudges now trigger send-nudge-push on insert.';
  RAISE NOTICE '⚠️  Requires: FIREBASE_SERVICE_ACCOUNT function secret + the';
  RAISE NOTICE '   send-nudge-push edge function deployed. See';
  RAISE NOTICE '   docs/PUSH_NOTIFICATIONS_SETUP.md.';
  RAISE NOTICE '';
END $$;
