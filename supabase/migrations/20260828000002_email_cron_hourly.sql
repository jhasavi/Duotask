-- ============================================================================
-- DuoTask: Reschedule the daily email digest to run hourly
-- ============================================================================
-- Pairs with 20260828000001_email_preferences_timezone.sql. The edge function
-- now decides per-user whether "now" falls in their local email_time hour, so
-- the cron trigger itself needs to fire every hour rather than once at 08:00
-- UTC. Requires the same Vault secrets as the original job
-- (see 20250625000005_setup_email_cron.sql).
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM vault.decrypted_secrets WHERE name = 'project_url'
  ) THEN
    RAISE EXCEPTION 'Vault secret "project_url" is missing.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM vault.decrypted_secrets WHERE name = 'anon_key'
  ) THEN
    RAISE EXCEPTION 'Vault secret "anon_key" is missing.';
  END IF;
END $$;

SELECT cron.unschedule('daily-email-digest') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'daily-email-digest'
);

-- Fire at the top of every hour; the edge function filters to users whose
-- local email_time falls in the current UTC hour and skips anyone already
-- sent today (their local date).
SELECT cron.schedule(
  'daily-email-digest',
  '0 * * * *',
  $$
  SELECT net.http_post(
    url := (
      SELECT decrypted_secret FROM vault.decrypted_secrets
      WHERE name = 'project_url'
    ) || '/functions/v1/daily-email-digest',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (
        SELECT decrypted_secret FROM vault.decrypted_secrets
        WHERE name = 'anon_key'
      )
    ),
    body := '{}'::jsonb
  ) AS request_id;
  $$
);

SELECT jobname, schedule, active FROM cron.job WHERE jobname = 'daily-email-digest';

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Daily email cron job rescheduled to run hourly.';
  RAISE NOTICE '⏰ Schedule: top of every hour (0 * * * *)';
  RAISE NOTICE '📧 Recipients: users with daily_email_enabled = true whose local email_time falls in this UTC hour';
  RAISE NOTICE '';
END $$;
