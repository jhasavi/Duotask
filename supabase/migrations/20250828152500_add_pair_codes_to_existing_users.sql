-- Add pair codes to existing users who don't have them
-- This migration ensures all users have pair codes for the new pairing system

-- Function to generate a random pair code
CREATE OR REPLACE FUNCTION generate_pair_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  pair_code TEXT;
BEGIN
  -- Generate a unique pair code
  pair_code := (
    SELECT string_agg(
      substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 
        (random() * 32)::int + 1, 1), ''
    ) FROM generate_series(1, 8)
  );
  
  RETURN pair_code;
END;
$$;

-- Update existing users who don't have pair codes
UPDATE public.usr 
SET pair_code = generate_pair_code()
WHERE pair_code IS NULL OR pair_code = '';

-- Ensure all pair codes are unique (in case of collisions)
DO $$
DECLARE
  user_record RECORD;
  new_pair_code TEXT;
  attempts INTEGER;
BEGIN
  FOR user_record IN 
    SELECT id, pair_code 
    FROM public.usr 
    WHERE pair_code IS NOT NULL
  LOOP
    attempts := 0;
    LOOP
      -- Check if this pair code is unique
      IF NOT EXISTS (
        SELECT 1 FROM public.usr 
        WHERE pair_code = user_record.pair_code 
        AND id != user_record.id
      ) THEN
        EXIT; -- Pair code is unique, continue to next user
      END IF;
      
      -- Generate a new pair code
      new_pair_code := generate_pair_code();
      
      -- Update the user with the new pair code
      UPDATE public.usr 
      SET pair_code = new_pair_code 
      WHERE id = user_record.id;
      
      attempts := attempts + 1;
      
      -- Prevent infinite loop
      IF attempts > 10 THEN
        RAISE EXCEPTION 'Could not generate unique pair code for user % after 10 attempts', user_record.id;
      END IF;
    END LOOP;
  END LOOP;
END $$;

-- Drop the temporary function
DROP FUNCTION generate_pair_code();

-- Log the results
DO $$
DECLARE
  total_users INTEGER;
  users_with_codes INTEGER;
BEGIN
  SELECT COUNT(*) INTO total_users FROM public.usr;
  SELECT COUNT(*) INTO users_with_codes FROM public.usr WHERE pair_code IS NOT NULL AND pair_code != '';
  
  RAISE NOTICE 'Migration complete: % users total, % users with pair codes', total_users, users_with_codes;
END $$;
