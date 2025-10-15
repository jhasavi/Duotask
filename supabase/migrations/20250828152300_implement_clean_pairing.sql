-- Implement Clean Pairing System (from PAIRING.md)
-- This migration implements the dyad-based pairing approach

-- =====================================================
-- 1. Create New Pair Table (Dyad)
-- =====================================================

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

-- =====================================================
-- 2. Update Tasks Table
-- =====================================================

-- Add new columns to tasks table
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS scope TEXT DEFAULT 'personal' CHECK (scope IN ('personal', 'shared'));
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS creator_id UUID REFERENCES public.usr(id) ON DELETE CASCADE;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS pair_id UUID REFERENCES public.pair(id) ON DELETE SET NULL;

-- =====================================================
-- 3. Create Indexes
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_pair_user_a ON public.pair(user_a);
CREATE INDEX IF NOT EXISTS idx_pair_user_b ON public.pair(user_b);
CREATE INDEX IF NOT EXISTS idx_pair_status ON public.pair(status);
CREATE INDEX IF NOT EXISTS idx_tasks_scope ON public.tasks(scope);
CREATE INDEX IF NOT EXISTS idx_tasks_creator_id ON public.tasks(creator_id);
CREATE INDEX IF NOT EXISTS idx_tasks_pair_id ON public.tasks(pair_id);

-- =====================================================
-- 4. Create Functions
-- =====================================================

-- Function to pair up two users
CREATE OR REPLACE FUNCTION public.fn_pair_up(partner_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_user_id UUID;
  user_a UUID;
  user_b UUID;
  pair_record RECORD;
BEGIN
  -- Get current user ID
  current_user_id := auth.uid();
  
  -- Validate partner
  IF partner_id IS NULL OR partner_id = current_user_id THEN
    RAISE EXCEPTION 'Invalid partner';
  END IF;
  
  -- Check if either user is already in an active pair
  IF EXISTS (
    SELECT 1 FROM public.pair 
    WHERE status = 'active' 
    AND (user_a = current_user_id OR user_b = current_user_id)
  ) THEN
    RAISE EXCEPTION 'One of the users is already paired';
  END IF;
  
  IF EXISTS (
    SELECT 1 FROM public.pair 
    WHERE status = 'active' 
    AND (user_a = partner_id OR user_b = partner_id)
  ) THEN
    RAISE EXCEPTION 'One of the users is already paired';
  END IF;
  
  -- Determine user_a and user_b (user_a < user_b)
  IF current_user_id < partner_id THEN
    user_a := current_user_id;
    user_b := partner_id;
  ELSE
    user_a := partner_id;
    user_b := current_user_id;
  END IF;
  
  -- Check if dyad exists
  SELECT * INTO pair_record FROM public.pair WHERE user_a = $1 AND user_b = $2;
  
  IF FOUND THEN
    -- Update existing dyad to active
    UPDATE public.pair SET status = 'active', updated_at = NOW() WHERE id = pair_record.id;
    RETURN pair_record.id;
  ELSE
    -- Create new dyad
    INSERT INTO public.pair (user_a, user_b, status) VALUES (user_a, user_b, 'active');
    RETURN currval(pg_get_serial_sequence('public.pair', 'id'));
  END IF;
END;
$$;

-- Function to unpair
CREATE OR REPLACE FUNCTION public.fn_unpair()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_user_id UUID;
BEGIN
  current_user_id := auth.uid();
  
  -- Deactivate any active pair containing the current user
  UPDATE public.pair 
  SET status = 'inactive', updated_at = NOW()
  WHERE status = 'active' 
  AND (user_a = current_user_id OR user_b = current_user_id);
END;
$$;

-- Function to get current pair info
CREATE OR REPLACE FUNCTION public.fn_get_current_pair()
RETURNS TABLE (
  pair_id UUID,
  partner_id UUID,
  partner_name TEXT,
  status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_user_id UUID;
BEGIN
  current_user_id := auth.uid();
  
  RETURN QUERY
  SELECT 
    p.id as pair_id,
    CASE 
      WHEN p.user_a = current_user_id THEN p.user_b
      ELSE p.user_a
    END as partner_id,
    u.name as partner_name,
    p.status
  FROM public.pair p
  JOIN public.usr u ON (
    CASE 
      WHEN p.user_a = current_user_id THEN p.user_b
      ELSE p.user_a
    END = u.id
  )
  WHERE p.status = 'active'
  AND (p.user_a = current_user_id OR p.user_b = current_user_id);
END;
$$;

-- Function to create a shared task
CREATE OR REPLACE FUNCTION public.fn_create_shared_task(
  task_title TEXT,
  task_description TEXT DEFAULT NULL,
  due_date TIMESTAMPTZ DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_user_id UUID;
  current_pair_id UUID;
  new_task_id UUID;
BEGIN
  current_user_id := auth.uid();
  
  -- Get current active pair
  SELECT pair_id INTO current_pair_id FROM public.fn_get_current_pair();
  
  IF current_pair_id IS NULL THEN
    RAISE EXCEPTION 'No active pair found';
  END IF;
  
  -- Create the task
  INSERT INTO public.tasks (
    title, 
    description, 
    scope, 
    creator_id, 
    pair_id, 
    owner_id,
    due_date,
    status
  ) VALUES (
    task_title,
    task_description,
    'shared',
    current_user_id,
    current_pair_id,
    current_user_id,
    due_date,
    'pending'
  ) RETURNING id INTO new_task_id;
  
  RETURN new_task_id;
END;
$$;

-- =====================================================
-- 5. Grant Permissions
-- =====================================================

GRANT EXECUTE ON FUNCTION public.fn_pair_up(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_unpair() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_get_current_pair() TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_create_shared_task(TEXT, TEXT, TIMESTAMPTZ) TO authenticated;

-- =====================================================
-- 6. Enable RLS and Create Policies
-- =====================================================

ALTER TABLE public.pair ENABLE ROW LEVEL SECURITY;

-- Pair policies
CREATE POLICY "Users can view their own pairs" ON public.pair
  FOR SELECT USING (auth.uid() = user_a OR auth.uid() = user_b);

CREATE POLICY "Users can update their own pairs" ON public.pair
  FOR UPDATE USING (auth.uid() = user_a OR auth.uid() = user_b);

-- Task policies (updated for new model)
DROP POLICY IF EXISTS "Users can view shared tasks" ON public.tasks;
CREATE POLICY "Users can view shared tasks" ON public.tasks
  FOR SELECT USING (
    scope = 'shared' AND
    pair_id IN (
      SELECT id FROM public.pair 
      WHERE status = 'active' 
      AND (user_a = auth.uid() OR user_b = auth.uid())
    )
  );

-- =====================================================
-- 7. Data Migration (Backfill)
-- =====================================================

-- Create dyads from existing pairings
INSERT INTO public.pair (user_a, user_b, status)
SELECT 
  CASE WHEN u1.id < u2.id THEN u1.id ELSE u2.id END as user_a,
  CASE WHEN u1.id < u2.id THEN u2.id ELSE u1.id END as user_b,
  'active' as status
FROM public.usr u1
JOIN public.usr u2 ON u1.paired_with = u2.id
WHERE u1.paired_with IS NOT NULL
ON CONFLICT (user_a, user_b) DO NOTHING;

-- Update existing tasks to set creator_id and scope
UPDATE public.tasks 
SET 
  creator_id = owner_id,
  scope = CASE WHEN pair_id IS NOT NULL THEN 'shared' ELSE 'personal' END
WHERE creator_id IS NULL;

-- Update shared tasks to use new pair_id
UPDATE public.tasks t
SET pair_id = p.id
FROM public.pair p
WHERE t.pair_id IS NOT NULL 
AND t.pair_id IN (p.user_a, p.user_b)
AND p.status = 'active';

-- =====================================================
-- 8. Create Triggers for Immutability
-- =====================================================

-- Prevent updates to creator_id and pair_id
CREATE OR REPLACE FUNCTION public.prevent_immutable_updates()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.creator_id IS DISTINCT FROM NEW.creator_id THEN
    RAISE EXCEPTION 'creator_id cannot be changed';
  END IF;
  
  IF OLD.pair_id IS DISTINCT FROM NEW.pair_id THEN
    RAISE EXCEPTION 'pair_id cannot be changed';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_immutable_task_updates
  BEFORE UPDATE ON public.tasks
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_immutable_updates();

-- =====================================================
-- 9. Validation Queries (for testing)
-- =====================================================

-- Uncomment to verify the migration:
-- SELECT 'Active pairs:' as info, COUNT(*) as count FROM public.pair WHERE status = 'active';
-- SELECT 'Shared tasks:' as info, COUNT(*) as count FROM public.tasks WHERE scope = 'shared';
-- SELECT 'Personal tasks:' as info, COUNT(*) as count FROM public.tasks WHERE scope = 'personal';
