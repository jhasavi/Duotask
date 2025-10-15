-- Complete Schema and Functions for DuoTask App
-- This migration creates all necessary tables and functions

-- =====================================================
-- 1. Complete Database Schema
-- =====================================================

-- Users table
CREATE TABLE IF NOT EXISTS public.usr (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  pair_code TEXT UNIQUE,
  paired_with UUID REFERENCES public.usr(id) ON DELETE SET NULL,
  pair_status TEXT DEFAULT 'unpaired',
  pair_request_from UUID REFERENCES public.usr(id) ON DELETE SET NULL,
  email_confirmed BOOLEAN DEFAULT false,
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tasks table
CREATE TABLE IF NOT EXISTS public.tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'pending',
  owner_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
  claimed_by UUID REFERENCES public.usr(id) ON DELETE SET NULL,
  pair_id UUID REFERENCES public.usr(id) ON DELETE SET NULL,
  repeat_type TEXT,
  due_date TIMESTAMPTZ,
  urgent BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pairing requests table
CREATE TABLE IF NOT EXISTS public.pairing_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  from_user_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
  to_user_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours')
);

-- Partner history table
CREATE TABLE IF NOT EXISTS public.partner_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
  partner_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
  partner_name TEXT NOT NULL,
  pair_count INTEGER DEFAULT 1,
  last_paired TIMESTAMPTZ DEFAULT NOW(),
  last_unpaired TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, partner_id)
);

-- Task pairing history table
CREATE TABLE IF NOT EXISTS public.task_pairing_history (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
  partner_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
  task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, partner_id, task_id)
);

-- =====================================================
-- 2. Create Indexes
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_usr_email ON public.usr(email);
CREATE INDEX IF NOT EXISTS idx_usr_pair_code ON public.usr(pair_code);
CREATE INDEX IF NOT EXISTS idx_usr_paired_with ON public.usr(paired_with);
CREATE INDEX IF NOT EXISTS idx_usr_pair_request_from ON public.usr(pair_request_from);
CREATE INDEX IF NOT EXISTS idx_usr_last_seen ON public.usr(last_seen);
CREATE INDEX IF NOT EXISTS idx_tasks_owner_id ON public.tasks(owner_id);
CREATE INDEX IF NOT EXISTS idx_tasks_pair_id ON public.tasks(pair_id);
CREATE INDEX IF NOT EXISTS idx_tasks_claimed_by ON public.tasks(claimed_by);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_pairing_requests_from_user_id ON public.pairing_requests(from_user_id);
CREATE INDEX IF NOT EXISTS idx_pairing_requests_to_user_id ON public.pairing_requests(to_user_id);
CREATE INDEX IF NOT EXISTS idx_partner_history_user_id ON public.partner_history(user_id);
CREATE INDEX IF NOT EXISTS idx_partner_history_partner_id ON public.partner_history(partner_id);
CREATE INDEX IF NOT EXISTS idx_task_pairing_history_user_id ON public.task_pairing_history(user_id);
CREATE INDEX IF NOT EXISTS idx_task_pairing_history_partner_id ON public.task_pairing_history(partner_id);
CREATE INDEX IF NOT EXISTS idx_task_pairing_history_task_id ON public.task_pairing_history(task_id);

-- =====================================================
-- 3. Create Functions
-- =====================================================

-- Function to get frequent partners for a user
CREATE OR REPLACE FUNCTION public.get_frequent_partners(p_user_id UUID)
RETURNS TABLE (
  partner_id UUID,
  partner_name TEXT,
  pair_count INTEGER,
  last_paired TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ph.partner_id,
    ph.partner_name,
    ph.pair_count,
    ph.last_paired
  FROM partner_history ph
  WHERE ph.user_id = p_user_id
  ORDER BY ph.pair_count DESC, ph.last_paired DESC
  LIMIT 10;
END;
$$;

-- Function to get tasks for a specific pairing
CREATE OR REPLACE FUNCTION public.get_tasks_for_pairing(
  p_user_id UUID,
  p_partner_id UUID
)
RETURNS TABLE (
  task_id UUID,
  task_title TEXT,
  task_description TEXT,
  task_status TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    tph.task_id,
    t.title as task_title,
    t.description as task_description,
    t.status as task_status,
    tph.created_at
  FROM task_pairing_history tph
  JOIN tasks t ON t.id = tph.task_id
  WHERE tph.user_id = p_user_id 
    AND tph.partner_id = p_partner_id
    AND tph.is_active = true
  ORDER BY tph.created_at DESC;
END;
$$;

-- Function to add partner history
CREATE OR REPLACE FUNCTION public.add_partner_history(
  p_user_id UUID,
  p_partner_id UUID,
  p_partner_name TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO partner_history (user_id, partner_id, partner_name, pair_count, last_paired)
  VALUES (p_user_id, p_partner_id, p_partner_name, 1, NOW())
  ON CONFLICT (user_id, partner_id)
  DO UPDATE SET
    pair_count = partner_history.pair_count + 1,
    last_paired = NOW(),
    partner_name = EXCLUDED.partner_name,
    is_active = true;
END;
$$;

-- Function to add task pairing history
CREATE OR REPLACE FUNCTION public.add_task_pairing_history(
  p_user_id UUID,
  p_partner_id UUID,
  p_task_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO task_pairing_history (user_id, partner_id, task_id, is_active, created_at)
  VALUES (p_user_id, p_partner_id, p_task_id, true, NOW())
  ON CONFLICT (user_id, partner_id, task_id)
  DO UPDATE SET
    is_active = true,
    created_at = NOW();
END;
$$;

-- Function to update partner history on unpair
CREATE OR REPLACE FUNCTION public.update_partner_history_on_unpair(
  p_user_id UUID,
  p_partner_id UUID,
  p_partner_name TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update partner history to mark as inactive
  UPDATE partner_history 
  SET is_active = false, 
      last_unpaired = NOW()
  WHERE user_id = p_user_id AND partner_id = p_partner_id;
  
  -- If no record exists, create one
  IF NOT FOUND THEN
    INSERT INTO partner_history (user_id, partner_id, partner_name, pair_count, last_paired, is_active)
    VALUES (p_user_id, p_partner_id, p_partner_name, 1, NOW(), false);
  END IF;
END;
$$;

-- Function to update task pairing history on unpair
CREATE OR REPLACE FUNCTION public.update_task_pairing_history_on_unpair(
  p_user_id UUID,
  p_partner_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Mark all shared tasks as inactive for this pairing
  UPDATE task_pairing_history 
  SET is_active = false
  WHERE user_id = p_user_id AND partner_id = p_partner_id;
END;
$$;

-- Function to pair users
CREATE OR REPLACE FUNCTION public.pair_users(
  p_user_id UUID,
  p_partner_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Update both users to be paired
  UPDATE public.usr SET 
    paired_with = p_partner_id,
    pair_status = 'paired',
    pair_request_from = null,
    updated_at = NOW()
  WHERE id = p_user_id;
  
  UPDATE public.usr SET 
    paired_with = p_user_id,
    pair_status = 'paired',
    pair_request_from = null,
    updated_at = NOW()
  WHERE id = p_partner_id;
END;
$$;

-- Function to unpair users
CREATE OR REPLACE FUNCTION public.unpair_users(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_partner_id UUID;
BEGIN
  -- Get the partner ID
  SELECT paired_with INTO v_partner_id FROM public.usr WHERE id = p_user_id;
  
  IF v_partner_id IS NOT NULL THEN
    -- Clear both sides of the pairing
    UPDATE public.usr SET 
      paired_with = null,
      pair_status = 'unpaired',
      updated_at = NOW()
    WHERE id IN (p_user_id, v_partner_id);
  END IF;
END;
$$;

-- Create the v1 version of unpair_users for backward compatibility
CREATE OR REPLACE FUNCTION public.unpair_users_v1(p_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Call the original unpair_users function
  PERFORM public.unpair_users(p_user_id);
END;
$$;

-- =====================================================
-- 4. Grant Permissions
-- =====================================================

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.get_frequent_partners(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tasks_for_pairing(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_partner_history(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_task_pairing_history(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_partner_history_on_unpair(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_task_pairing_history_on_unpair(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pair_users(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unpair_users(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unpair_users_v1(UUID) TO authenticated;

-- =====================================================
-- 5. Enable RLS and Create Policies
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.usr ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pairing_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_pairing_history ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for usr table
CREATE POLICY "Users can view their own profile" ON public.usr
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON public.usr
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can view paired users" ON public.usr
  FOR SELECT USING (
    auth.uid() = paired_with OR 
    paired_with = auth.uid()
  );

-- Create RLS policies for tasks table
CREATE POLICY "Users can view their own tasks" ON public.tasks
  FOR SELECT USING (auth.uid() = owner_id);

CREATE POLICY "Users can view shared tasks" ON public.tasks
  FOR SELECT USING (
    auth.uid() = owner_id OR 
    auth.uid() = pair_id OR
    owner_id = (SELECT paired_with FROM public.usr WHERE id = auth.uid())
  );

CREATE POLICY "Users can insert their own tasks" ON public.tasks
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can update their own tasks" ON public.tasks
  FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "Users can delete their own tasks" ON public.tasks
  FOR DELETE USING (auth.uid() = owner_id);

-- Create RLS policies for other tables
CREATE POLICY "Users can view their own notifications" ON public.notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own pairing requests" ON public.pairing_requests
  FOR SELECT USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);

CREATE POLICY "Users can view their own partner history" ON public.partner_history
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own partner history" ON public.partner_history
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own partner history" ON public.partner_history
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own task pairing history" ON public.task_pairing_history
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own task pairing history" ON public.task_pairing_history
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own task pairing history" ON public.task_pairing_history
  FOR UPDATE USING (auth.uid() = user_id);
