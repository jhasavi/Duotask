-- ============================================================================
-- Lifecycle emails
--
-- Three emails, each sent at most once per user, by the lifecycle-emails
-- edge function on an hourly cron:
--
--   invite_partner  1–7 days after sign-up, while still unpaired.
--                   Pairing is the step that makes DuoTask useful.
--   tips            3–14 days after sign-up: typing tasks naturally,
--                   repeating chores, sending a task by link.
--   trial_ending    A Premium trial ends within 3 days.
--
-- Rules, all enforced here so the edge function stays a thin sender:
--   * Only between 09:00 and 19:59 in the user's timezone
--     (email_preferences.timezone, defaulting to UTC).
--   * At most one lifecycle email per user per run, and none within 20 hours
--     of the previous one. Priority: trial_ending, invite_partner, tips.
--   * invite_partner and tips respect email_preferences
--     .lifecycle_emails_enabled. trial_ending is a billing notice and is sent
--     regardless.
--   * The sign-up windows mean people who signed up before this shipped get
--     nothing: no surprise blast to old accounts.
--
-- Sending is claim -> send -> finish. claim_lifecycle_emails() inserts a
-- 'sending' row per email (unique per user and kind), so two overlapping
-- runs can't send the same email. finish_lifecycle_email() marks it 'sent',
-- or 'failed' to be retried next run, up to 3 attempts. A run that dies
-- mid-send leaves 'sending' rows; they are released after an hour.
--
-- Anyone holding the anon key can call the edge function (as with the daily
-- digest), but it can only send emails that are already due, once each.
-- ============================================================================

BEGIN;

ALTER TABLE public.email_preferences
  ADD COLUMN IF NOT EXISTS lifecycle_emails_enabled BOOLEAN NOT NULL DEFAULT TRUE;

CREATE TABLE IF NOT EXISTS public.lifecycle_emails (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('invite_partner', 'tips', 'trial_ending')),
  status TEXT NOT NULL DEFAULT 'sending'
    CHECK (status IN ('sending', 'sent', 'failed')),
  attempts INT NOT NULL DEFAULT 1,
  claimed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at TIMESTAMPTZ,
  UNIQUE (user_id, kind)
);

ALTER TABLE public.lifecycle_emails ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lifecycle_emails FROM PUBLIC, anon, authenticated;

ALTER TABLE analytics.events DROP CONSTRAINT IF EXISTS events_event_check;
ALTER TABLE analytics.events ADD CONSTRAINT events_event_check CHECK (event IN (
  'signup', 'pair_created', 'task_created', 'task_completed',
  'task_uncompleted', 'nudge_sent', 'premium_started', 'premium_ended',
  'share_created', 'share_opened', 'share_accepted', 'share_declined',
  'share_done', 'share_claimed',
  'paywall_viewed',
  'pair_invite_sent', 'pair_invite_opened',
  'lifecycle_email_sent'
));

-- The hour of day in tz, falling back to UTC for a timezone Postgres doesn't
-- know, so one bad value can't break the whole run.
CREATE OR REPLACE FUNCTION public._local_hour(p_tz TEXT, p_at TIMESTAMPTZ)
RETURNS INT
LANGUAGE plpgsql
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  RETURN extract(hour FROM p_at AT TIME ZONE COALESCE(NULLIF(p_tz, ''), 'UTC'))::INT;
EXCEPTION WHEN OTHERS THEN
  RETURN extract(hour FROM p_at AT TIME ZONE 'UTC')::INT;
END;
$$;

REVOKE ALL ON FUNCTION public._local_hour(TEXT, TIMESTAMPTZ) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.claim_lifecycle_emails(p_limit INT DEFAULT 100)
RETURNS TABLE (
  email_id BIGINT,
  user_id UUID,
  kind TEXT,
  email TEXT,
  display_name TEXT,
  partner_name TEXT,
  timezone TEXT,
  trial_ends_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
#variable_conflict use_column
BEGIN
  -- Release claims from a run that died mid-send.
  UPDATE public.lifecycle_emails le
  SET status = 'failed'
  WHERE le.status = 'sending'
    AND le.claimed_at < now() - interval '1 hour';

  RETURN QUERY
  WITH base AS (
    SELECT u.id,
           u.email,
           u.display_name,
           u.created_at,
           u.paired_with_id,
           u.premium_until,
           COALESCE(ep.timezone, 'UTC') AS tz,
           COALESCE(ep.lifecycle_emails_enabled, TRUE) AS opted_in,
           b.subscription_status
    FROM public.users u
    LEFT JOIN public.email_preferences ep ON ep.user_id = u.id
    LEFT JOIN public.billing_customers b ON b.user_id = u.id
    WHERE u.email IS NOT NULL
      AND public._local_hour(COALESCE(ep.timezone, 'UTC'), now()) BETWEEN 9 AND 19
      -- Nothing within 20 hours of the last lifecycle email.
      AND NOT EXISTS (
        SELECT 1 FROM public.lifecycle_emails le
        WHERE le.user_id = u.id
          AND le.status = 'sent'
          AND le.sent_at > now() - interval '20 hours'
      )
  ),
  candidates AS (
    SELECT b.id, 'trial_ending'::TEXT AS kind, 1 AS priority
    FROM base b
    WHERE b.subscription_status = 'trialing'
      AND b.premium_until > now()
      AND b.premium_until <= now() + interval '3 days'
    UNION ALL
    SELECT b.id, 'invite_partner', 2
    FROM base b
    WHERE b.opted_in
      AND b.paired_with_id IS NULL
      AND b.created_at <= now() - interval '1 day'
      AND b.created_at > now() - interval '7 days'
    UNION ALL
    SELECT b.id, 'tips', 3
    FROM base b
    WHERE b.opted_in
      AND b.created_at <= now() - interval '3 days'
      AND b.created_at > now() - interval '14 days'
  ),
  eligible AS (
    SELECT c.*
    FROM candidates c
    WHERE NOT EXISTS (
      SELECT 1 FROM public.lifecycle_emails le
      WHERE le.user_id = c.id
        AND le.kind = c.kind
        AND (le.status IN ('sent', 'sending') OR le.attempts >= 3)
    )
  ),
  picked AS (
    SELECT DISTINCT ON (e.id) e.id, e.kind
    FROM eligible e
    ORDER BY e.id, e.priority
    LIMIT p_limit
  ),
  claimed AS (
    INSERT INTO public.lifecycle_emails AS le (user_id, kind)
    SELECT p.id, p.kind FROM picked p
    ON CONFLICT (user_id, kind) DO UPDATE
      SET status = 'sending',
          claimed_at = now(),
          attempts = le.attempts + 1
      WHERE le.status = 'failed' AND le.attempts < 3
    RETURNING le.id, le.user_id, le.kind
  )
  SELECT c.id,
         c.user_id,
         c.kind,
         b.email,
         b.display_name,
         partner.display_name,
         b.tz,
         CASE WHEN c.kind = 'trial_ending' THEN b.premium_until END
  FROM claimed c
  JOIN base b ON b.id = c.user_id
  LEFT JOIN public.users partner ON partner.id = b.paired_with_id;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_lifecycle_emails(INT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_lifecycle_emails(INT) TO service_role;

CREATE OR REPLACE FUNCTION public.finish_lifecycle_email(
  p_email_id BIGINT,
  p_sent BOOLEAN
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  r public.lifecycle_emails;
BEGIN
  UPDATE public.lifecycle_emails
  SET status = CASE WHEN p_sent THEN 'sent' ELSE 'failed' END,
      sent_at = CASE WHEN p_sent THEN now() ELSE sent_at END
  WHERE id = p_email_id AND status = 'sending'
  RETURNING * INTO r;

  IF FOUND AND p_sent THEN
    PERFORM analytics.log_event(
      'lifecycle_email_sent', r.user_id, NULL,
      jsonb_build_object('kind', r.kind)
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.finish_lifecycle_email(BIGINT, BOOLEAN) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finish_lifecycle_email(BIGINT, BOOLEAN) TO service_role;

COMMIT;

-- ----------------------------------------------------------------------------
-- Hourly trigger, a quarter past so it doesn't collide with the digest.
-- Needs the same Vault secrets as 20260828000002_email_cron_hourly.sql.
-- ----------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.decrypted_secrets WHERE name = 'project_url') THEN
    RAISE EXCEPTION 'Vault secret "project_url" is missing.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM vault.decrypted_secrets WHERE name = 'anon_key') THEN
    RAISE EXCEPTION 'Vault secret "anon_key" is missing.';
  END IF;
END $$;

SELECT cron.unschedule('lifecycle-emails') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'lifecycle-emails'
);

SELECT cron.schedule(
  'lifecycle-emails',
  '15 * * * *',
  $$
  SELECT net.http_post(
    url := (
      SELECT decrypted_secret FROM vault.decrypted_secrets
      WHERE name = 'project_url'
    ) || '/functions/v1/lifecycle-emails',
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
