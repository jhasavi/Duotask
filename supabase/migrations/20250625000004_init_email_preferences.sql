-- ============================================================================
-- Initialize Email Preferences for Existing Users
-- Run this in Supabase SQL Editor to enable daily emails for all users
-- ============================================================================

-- Insert email preferences for all existing users who don't have them yet
INSERT INTO email_preferences (user_id, daily_email_enabled, email_time)
SELECT 
  id as user_id,
  TRUE as daily_email_enabled,
  '08:00:00'::TIME as email_time
FROM users
WHERE id NOT IN (SELECT user_id FROM email_preferences)
ON CONFLICT (user_id) DO NOTHING;

-- Verify the insertion
SELECT 
  u.email,
  u.display_name,
  ep.daily_email_enabled,
  ep.email_time,
  ep.last_email_sent_at
FROM users u
JOIN email_preferences ep ON u.id = ep.user_id
ORDER BY u.email;

-- Success message
DO $$
DECLARE
  user_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO user_count FROM email_preferences WHERE daily_email_enabled = TRUE;
  
  RAISE NOTICE '';
  RAISE NOTICE '✅ Email preferences initialized!';
  RAISE NOTICE '';
  RAISE NOTICE '📊 Total users with daily emails enabled: %', user_count;
  RAISE NOTICE '⏰ Default time: 8:00 AM';
  RAISE NOTICE '';
  RAISE NOTICE '🚀 Ready to send emails!';
END $$;
