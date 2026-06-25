-- ============================================================================
-- DuoTask: Setup Daily Email Cron Job
-- Run this in Supabase SQL Editor after deploying the edge function
-- ============================================================================

-- 1. Enable pg_cron extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Enable pg_net extension for HTTP requests (if not already enabled)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 3. Delete existing cron job if it exists
SELECT cron.unschedule('daily-email-digest') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'daily-email-digest'
);

-- 4. Schedule daily email at 8 AM UTC (3 AM EST, 12 AM PST)
-- Adjust the time as needed for your timezone
SELECT cron.schedule(
  'daily-email-digest',
  '0 8 * * *',  -- Every day at 8 AM UTC
  $$
  SELECT
    net.http_post(
      url:='https://xqhlnuvpogiolzkucupt.supabase.co/functions/v1/daily-email-digest',
      headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhxaGxudXZwb2dpb2x6a3VjdXB0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE5MTA1NzgsImV4cCI6MjA2NzQ4NjU3OH0.9lw-X6mjpPFfTqpiiTEOpzWZEfqnPkW0ADA6XfbLsNw"}'::jsonb,
      body:='{}'::jsonb
    ) as request_id;
  $$
);

-- 5. Verify the cron job was created
SELECT * FROM cron.job WHERE jobname = 'daily-email-digest';

-- 6. Check recent cron job runs (after it runs once)
-- SELECT * FROM cron.job_run_details WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'daily-email-digest') ORDER BY start_time DESC LIMIT 10;

-- ============================================================================
-- READY TO RUN! The Authorization token has been configured with your anon key.
-- Copy this entire file and paste into Supabase SQL Editor, then click RUN.
-- ============================================================================

-- Success message
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '✅ Daily email cron job scheduled successfully!';
  RAISE NOTICE '';
  RAISE NOTICE '⏰ Schedule: Every day at 8 AM UTC';
  RAISE NOTICE '📧 Sends emails to all users with daily_email_enabled=true';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  NEXT STEP: Update the Authorization token in the cron job';
  RAISE NOTICE '   1. Go to: https://supabase.com/dashboard/project/xqhlnuvpogiolzkucupt/settings/api';
  RAISE NOTICE '   2. Copy your anon (public) key';
  RAISE NOTICE '   3. Replace the "example" token in this script';
  RAISE NOTICE '   4. Re-run this script';
END $$;
