-- ============================================================================
-- DuoTask: Setup Daily Email Cron Job
-- Run this in Supabase SQL Editor after deploying the edge function.
-- ============================================================================
--
-- PREREQUISITE — store the credentials in Vault first, so no key is ever
-- written into this file or into the cron job definition. Run once:
--
--   select vault.create_secret(
--     'https://<project-ref>.supabase.co', 'project_url');
--   select vault.create_secret(
--     '<anon key>', 'anon_key');
--
-- To rotate a key later, update the Vault secret; the cron job picks up the
-- new value on its next run with no migration change.
-- ============================================================================

-- 1. Extensions
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS supabase_vault;

-- 2. Fail loudly if the Vault secrets are missing, rather than scheduling a
--    job that silently 401s every morning.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM vault.decrypted_secrets WHERE name = 'project_url'
  ) THEN
    RAISE EXCEPTION 'Vault secret "project_url" is missing. See the header of this file.';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM vault.decrypted_secrets WHERE name = 'anon_key'
  ) THEN
    RAISE EXCEPTION 'Vault secret "anon_key" is missing. See the header of this file.';
  END IF;
END $$;

-- 3. Remove any existing job so this migration is re-runnable.
SELECT cron.unschedule('daily-email-digest') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'daily-email-digest'
);

-- 4. Schedule daily email at 8 AM UTC.
--    NOTE: this fires at a single UTC instant for every user regardless of
--    their local timezone. Per-user send times are tracked as a known gap.
SELECT cron.schedule(
  'daily-email-digest',
  '0 8 * * *',
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

-- 5. Verify
SELECT jobname, schedule, active FROM cron.job WHERE jobname = 'daily-email-digest';

-- 6. Check recent runs (after it has fired at least once)
-- SELECT * FROM cron.job_run_details
--   WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'daily-email-digest')
--   ORDER BY start_time DESC LIMIT 10;

DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Daily email cron job scheduled.';
  RAISE NOTICE '⏰ Schedule: every day at 08:00 UTC';
  RAISE NOTICE '📧 Recipients: users with daily_email_enabled = true';
  RAISE NOTICE '🔐 Credentials read from Vault at run time (no keys in SQL).';
  RAISE NOTICE '';
END $$;
