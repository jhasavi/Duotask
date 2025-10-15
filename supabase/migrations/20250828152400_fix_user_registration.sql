-- Fix User Registration Issue
-- This migration ensures users are properly added to the database after registration

-- Drop old policies that depend on old columns
DROP POLICY IF EXISTS "Users can view paired users" ON public.usr;
DROP POLICY IF EXISTS "Users can view own profile" ON public.usr;
DROP POLICY IF EXISTS "Users can update own profile" ON public.usr;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.usr;

-- Drop old columns from usr table if they exist
ALTER TABLE public.usr DROP COLUMN IF EXISTS paired_with;
ALTER TABLE public.usr DROP COLUMN IF EXISTS pair_status;
ALTER TABLE public.usr DROP COLUMN IF EXISTS pair_request_from;

-- Ensure the usr table has the correct structure for clean pairing
CREATE TABLE IF NOT EXISTS public.usr (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  pair_code TEXT UNIQUE,
  email_confirmed BOOLEAN DEFAULT false,
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure the pair table exists
CREATE TABLE IF NOT EXISTS public.pair (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_a UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
  user_b UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'inactive' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_a, user_b),
  CONSTRAINT user_a_less_than_user_b CHECK (user_a < user_b)
);

-- Ensure the tasks table has the correct structure
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS scope TEXT DEFAULT 'personal' CHECK (scope IN ('personal', 'shared'));
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS creator_id UUID REFERENCES public.usr(id) ON DELETE CASCADE;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS pair_id UUID REFERENCES public.pair(id) ON DELETE SET NULL;

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_usr_email ON public.usr(email);
CREATE INDEX IF NOT EXISTS idx_usr_pair_code ON public.usr(pair_code);
CREATE INDEX IF NOT EXISTS idx_pair_user_a ON public.pair(user_a);
CREATE INDEX IF NOT EXISTS idx_pair_user_b ON public.pair(user_b);
CREATE INDEX IF NOT EXISTS idx_pair_status ON public.pair(status);
CREATE INDEX IF NOT EXISTS idx_tasks_scope ON public.tasks(scope);
CREATE INDEX IF NOT EXISTS idx_tasks_creator_id ON public.tasks(creator_id);
CREATE INDEX IF NOT EXISTS idx_tasks_pair_id ON public.tasks(pair_id);

-- Create or replace the ensure_usr_exists function
CREATE OR REPLACE FUNCTION public.ensure_usr_exists(user_id UUID, user_email TEXT, user_name TEXT DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
  
  -- Insert or update user in usr table
  INSERT INTO public.usr (id, email, name, pair_code, email_confirmed)
  VALUES (user_id, user_email, COALESCE(user_name, split_part(user_email, '@', 1)), pair_code, true)
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = COALESCE(EXCLUDED.name, usr.name),
    email_confirmed = true,
    updated_at = NOW();
    
  -- If name was provided and different, update it
  IF user_name IS NOT NULL AND user_name != '' THEN
    UPDATE public.usr SET name = user_name WHERE id = user_id;
  END IF;
END;
$$;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.usr TO anon, authenticated;
GRANT ALL ON public.pair TO anon, authenticated;
GRANT ALL ON public.tasks TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_usr_exists TO anon, authenticated;

-- Enable RLS
ALTER TABLE public.usr ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pair ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for usr table
DROP POLICY IF EXISTS "Users can view own profile" ON public.usr;
CREATE POLICY "Users can view own profile" ON public.usr
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.usr;
CREATE POLICY "Users can update own profile" ON public.usr
  FOR UPDATE USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.usr;
CREATE POLICY "Users can insert own profile" ON public.usr
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Create RLS policies for pair table
DROP POLICY IF EXISTS "Users can view own pairs" ON public.pair;
CREATE POLICY "Users can view own pairs" ON public.pair
  FOR SELECT USING (auth.uid() = user_a OR auth.uid() = user_b);

DROP POLICY IF EXISTS "Users can create own pairs" ON public.pair;
CREATE POLICY "Users can create own pairs" ON public.pair
  FOR INSERT WITH CHECK (auth.uid() = user_a OR auth.uid() = user_b);

DROP POLICY IF EXISTS "Users can update own pairs" ON public.pair;
CREATE POLICY "Users can update own pairs" ON public.pair
  FOR UPDATE USING (auth.uid() = user_a OR auth.uid() = user_b);

-- Create RLS policies for tasks table
DROP POLICY IF EXISTS "Users can view own and shared tasks" ON public.tasks;
CREATE POLICY "Users can view own and shared tasks" ON public.tasks
  FOR SELECT USING (
    auth.uid() = owner_id OR 
    (scope = 'shared' AND pair_id IN (
      SELECT id FROM public.pair 
      WHERE status = 'active' AND (user_a = auth.uid() OR user_b = auth.uid())
    ))
  );

DROP POLICY IF EXISTS "Users can create own tasks" ON public.tasks;
CREATE POLICY "Users can create own tasks" ON public.tasks
  FOR INSERT WITH CHECK (auth.uid() = creator_id);

DROP POLICY IF EXISTS "Users can update own and shared tasks" ON public.tasks;
CREATE POLICY "Users can update own and shared tasks" ON public.tasks
  FOR UPDATE USING (
    auth.uid() = owner_id OR 
    (scope = 'shared' AND pair_id IN (
      SELECT id FROM public.pair 
      WHERE status = 'active' AND (user_a = auth.uid() OR user_b = auth.uid())
    ))
  );

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
DROP TRIGGER IF EXISTS update_usr_updated_at ON public.usr;
CREATE TRIGGER update_usr_updated_at 
    BEFORE UPDATE ON public.usr 
    FOR EACH ROW 
    EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_pair_updated_at ON public.pair;
CREATE TRIGGER update_pair_updated_at 
    BEFORE UPDATE ON public.pair 
    FOR EACH ROW 
    EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_tasks_updated_at ON public.tasks;
CREATE TRIGGER update_tasks_updated_at 
    BEFORE UPDATE ON public.tasks 
    FOR EACH ROW 
    EXECUTE FUNCTION public.update_updated_at_column();
