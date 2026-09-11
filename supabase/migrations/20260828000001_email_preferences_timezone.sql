-- ============================================================================
-- DuoTask: Per-user timezone for the daily email digest
-- ============================================================================
-- The digest previously fired at a single 08:00 UTC instant for every user
-- (see 20250625000005_setup_email_cron.sql). This adds a timezone column so
-- the cron job (rescheduled to run hourly) and the edge function can send
-- each user's digest at their own local `email_time`.
-- ============================================================================

BEGIN;

ALTER TABLE email_preferences
  ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'UTC';

COMMENT ON COLUMN email_preferences.timezone IS
  'IANA timezone name (e.g. America/New_York). email_time is interpreted in this zone.';

-- Validate against pg_timezone_names so a bad value fails fast instead of
-- silently never matching in the edge function. (A CHECK constraint can't
-- subquery a catalog view, so this is enforced with a trigger instead.)
CREATE OR REPLACE FUNCTION validate_email_preferences_timezone()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = NEW.timezone) THEN
    RAISE EXCEPTION 'Invalid timezone: %', NEW.timezone;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS email_preferences_timezone_check ON email_preferences;
CREATE TRIGGER email_preferences_timezone_check
  BEFORE INSERT OR UPDATE OF timezone ON email_preferences
  FOR EACH ROW
  EXECUTE FUNCTION validate_email_preferences_timezone();

COMMIT;
