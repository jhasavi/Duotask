-- ============================================================================
-- DuoTask v1.2: Daily Email Notifications
-- Run this entire script in Supabase SQL Editor
-- ============================================================================

BEGIN;

-- 1. Create email_preferences table
CREATE TABLE IF NOT EXISTS email_preferences (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  daily_email_enabled BOOLEAN DEFAULT TRUE,
  email_time TIME DEFAULT '08:00:00',
  last_email_sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Enable RLS on email_preferences
ALTER TABLE email_preferences ENABLE ROW LEVEL SECURITY;

-- 3. Create RLS policies for email_preferences
DROP POLICY IF EXISTS "Users can view their own email preferences" ON email_preferences;
CREATE POLICY "Users can view their own email preferences"
  ON email_preferences FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own email preferences" ON email_preferences;
CREATE POLICY "Users can update their own email preferences"
  ON email_preferences FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own email preferences" ON email_preferences;
CREATE POLICY "Users can insert their own email preferences"
  ON email_preferences FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 4. Create function to get daily email data for a user
CREATE OR REPLACE FUNCTION get_daily_email_data(user_uuid UUID)
RETURNS JSON AS $$
DECLARE
  user_email TEXT;
  user_name TEXT;
  partner_name TEXT;
  result JSON;
  personal_unclaimed INTEGER;
  personal_claimed INTEGER;
  group_unclaimed INTEGER;
  group_claimed_by_user INTEGER;
  group_claimed_by_partner INTEGER;
  partner_id UUID;
BEGIN
  -- Get user info
  SELECT email, display_name, paired_with_id, paired_with_name
  INTO user_email, user_name, partner_id, partner_name
  FROM users
  WHERE id = user_uuid;

  -- Count personal tasks
  SELECT 
    COUNT(*) FILTER (WHERE status = 'unclaimed'),
    COUNT(*) FILTER (WHERE status = 'claimed')
  INTO personal_unclaimed, personal_claimed
  FROM tasks
  WHERE created_by_id = user_uuid
    AND visibility = 'personal'
    AND status != 'completed';

  -- Count group tasks
  IF partner_id IS NOT NULL THEN
    SELECT 
      COUNT(*) FILTER (WHERE status = 'unclaimed'),
      COUNT(*) FILTER (WHERE status = 'claimed' AND claimed_by_id = user_uuid),
      COUNT(*) FILTER (WHERE status = 'claimed' AND claimed_by_id = partner_id)
    INTO group_unclaimed, group_claimed_by_user, group_claimed_by_partner
    FROM tasks
    WHERE visibility = 'group'
      AND (created_by_id = user_uuid OR created_by_id = partner_id)
      AND status != 'completed';
  ELSE
    group_unclaimed := 0;
    group_claimed_by_user := 0;
    group_claimed_by_partner := 0;
  END IF;

  -- Build JSON result
  result := json_build_object(
    'user_email', user_email,
    'user_name', COALESCE(user_name, 'User'),
    'partner_name', partner_name,
    'has_partner', partner_id IS NOT NULL,
    'personal_unclaimed', personal_unclaimed,
    'personal_claimed', personal_claimed,
    'group_unclaimed', group_unclaimed,
    'group_claimed_by_user', group_claimed_by_user,
    'group_claimed_by_partner', group_claimed_by_partner,
    'total_open', personal_unclaimed + personal_claimed + group_unclaimed + group_claimed_by_user + group_claimed_by_partner
  );

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Create function to get task details for email
CREATE OR REPLACE FUNCTION get_daily_email_tasks(user_uuid UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
  partner_id UUID;
BEGIN
  -- Get partner ID
  SELECT paired_with_id INTO partner_id
  FROM users
  WHERE id = user_uuid;

  -- Get task details grouped by category
  result := json_build_object(
    'personal_unclaimed', (
      SELECT COALESCE(json_agg(json_build_object(
        'id', id,
        'title', title,
        'priority', priority,
        'due_date', due_date
      )), '[]'::json)
      FROM tasks
      WHERE created_by_id = user_uuid
        AND visibility = 'personal'
        AND status = 'unclaimed'
      ORDER BY 
        CASE WHEN priority = 'urgent' THEN 0 ELSE 1 END,
        CASE WHEN due_date IS NULL THEN 1 ELSE 0 END,
        due_date ASC
      LIMIT 10
    ),
    'personal_claimed', (
      SELECT COALESCE(json_agg(json_build_object(
        'id', id,
        'title', title,
        'priority', priority,
        'due_date', due_date
      )), '[]'::json)
      FROM tasks
      WHERE created_by_id = user_uuid
        AND visibility = 'personal'
        AND status = 'claimed'
      ORDER BY 
        CASE WHEN priority = 'urgent' THEN 0 ELSE 1 END,
        CASE WHEN due_date IS NULL THEN 1 ELSE 0 END,
        due_date ASC
      LIMIT 10
    ),
    'group_unclaimed', (
      SELECT COALESCE(json_agg(json_build_object(
        'id', id,
        'title', title,
        'priority', priority,
        'due_date', due_date,
        'created_by_me', created_by_id = user_uuid
      )), '[]'::json)
      FROM tasks
      WHERE visibility = 'group'
        AND (created_by_id = user_uuid OR created_by_id = partner_id)
        AND status = 'unclaimed'
      ORDER BY 
        CASE WHEN priority = 'urgent' THEN 0 ELSE 1 END,
        CASE WHEN due_date IS NULL THEN 1 ELSE 0 END,
        due_date ASC
      LIMIT 10
    ),
    'group_claimed_by_user', (
      SELECT COALESCE(json_agg(json_build_object(
        'id', id,
        'title', title,
        'priority', priority,
        'due_date', due_date
      )), '[]'::json)
      FROM tasks
      WHERE visibility = 'group'
        AND claimed_by_id = user_uuid
        AND status = 'claimed'
      ORDER BY 
        CASE WHEN priority = 'urgent' THEN 0 ELSE 1 END,
        CASE WHEN due_date IS NULL THEN 1 ELSE 0 END,
        due_date ASC
      LIMIT 10
    ),
    'group_claimed_by_partner', (
      SELECT COALESCE(json_agg(json_build_object(
        'id', id,
        'title', title,
        'priority', priority,
        'due_date', due_date
      )), '[]'::json)
      FROM tasks
      WHERE visibility = 'group'
        AND claimed_by_id = partner_id
        AND status = 'claimed'
      ORDER BY 
        CASE WHEN priority = 'urgent' THEN 0 ELSE 1 END,
        CASE WHEN due_date IS NULL THEN 1 ELSE 0 END,
        due_date ASC
      LIMIT 10
    )
  );

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Success messages
DO $$
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '🎉 v1.2 Migration completed successfully!';
  RAISE NOTICE '';
  RAISE NOTICE '✅ Created email_preferences table';
  RAISE NOTICE '✅ Set up RLS policies for email preferences';
  RAISE NOTICE '✅ Created get_daily_email_data function';
  RAISE NOTICE '✅ Created get_daily_email_tasks function';
  RAISE NOTICE '';
  RAISE NOTICE '🚀 Features enabled:';
  RAISE NOTICE '  - Daily email notifications (enabled by default)';
  RAISE NOTICE '  - User-customizable email preferences';
  RAISE NOTICE '';
  RAISE NOTICE '⚠️  Next steps:';
  RAISE NOTICE '  - Set up Supabase Edge Function for sending emails';
  RAISE NOTICE '  - Configure email templates';
  RAISE NOTICE '  - Set up cron job to trigger daily emails';
END $$;

COMMIT;

-- ============================================================================
-- Migration Complete!
-- ============================================================================
