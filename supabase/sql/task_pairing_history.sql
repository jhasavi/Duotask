-- Task Pairing History Table
-- Tracks which pairing a task was created under for proper restoration
CREATE TABLE IF NOT EXISTS public.task_pairing_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
    partner_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure unique task-user-partner combinations
    UNIQUE(task_id, user_id, partner_id)
);

-- Index for efficient queries
CREATE INDEX IF NOT EXISTS idx_task_pairing_history_task_id ON public.task_pairing_history(task_id);
CREATE INDEX IF NOT EXISTS idx_task_pairing_history_user_partner ON public.task_pairing_history(user_id, partner_id);

-- Enable RLS
ALTER TABLE public.task_pairing_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own task pairing history" ON public.task_pairing_history
    FOR SELECT USING (auth.uid() = user_id OR auth.uid() = partner_id);

CREATE POLICY "Users can insert their own task pairing history" ON public.task_pairing_history
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Function to add task pairing history
CREATE OR REPLACE FUNCTION public.add_task_pairing_history(
    p_task_id UUID,
    p_user_id UUID,
    p_partner_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.task_pairing_history (
        task_id,
        user_id,
        partner_id
    ) VALUES (
        p_task_id,
        p_user_id,
        p_partner_id
    )
    ON CONFLICT (task_id, user_id, partner_id) DO NOTHING;
END;
$$;

-- Function to get tasks for a specific pairing
CREATE OR REPLACE FUNCTION public.get_tasks_for_pairing(
    p_user_id UUID,
    p_partner_id UUID
)
RETURNS TABLE(
    task_id UUID,
    title TEXT,
    status TEXT,
    owner_id UUID,
    claimed_by UUID,
    pair_id UUID,
    repeat_type TEXT,
    due_date TIMESTAMP WITH TIME ZONE,
    urgent BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.title,
        t.status,
        t.owner_id,
        t.claimed_by,
        t.pair_id,
        t.repeat_type,
        t.due_date,
        t.urgent,
        t.created_at,
        t.updated_at
    FROM public.tasks t
    INNER JOIN public.task_pairing_history tph ON t.id = tph.task_id
    WHERE (tph.user_id = p_user_id AND tph.partner_id = p_partner_id)
       OR (tph.user_id = p_partner_id AND tph.partner_id = p_user_id)
    ORDER BY t.created_at DESC;
END;
$$;

-- Grant permissions
GRANT SELECT, INSERT ON public.task_pairing_history TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_task_pairing_history(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tasks_for_pairing(UUID, UUID) TO authenticated;

-- Update task creation to automatically add pairing history
CREATE OR REPLACE FUNCTION public.create_task_with_pairing_history(
    p_title TEXT,
    p_owner_id UUID,
    p_pair_id UUID,
    p_status TEXT DEFAULT 'unclaimed',
    p_repeat_type TEXT DEFAULT 'none',
    p_due_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_urgent BOOLEAN DEFAULT FALSE
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    new_task_id UUID;
BEGIN
    -- Create the task
    INSERT INTO public.tasks (
        title,
        owner_id,
        pair_id,
        status,
        repeat_type,
        due_date,
        urgent
    ) VALUES (
        p_title,
        p_owner_id,
        p_pair_id,
        p_status,
        p_repeat_type,
        p_due_date,
        p_urgent
    ) RETURNING id INTO new_task_id;
    
    -- Add pairing history if this is a shared task
    IF p_pair_id IS NOT NULL THEN
        PERFORM public.add_task_pairing_history(new_task_id, p_owner_id, p_pair_id);
    END IF;
    
    RETURN new_task_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_task_with_pairing_history(TEXT, UUID, UUID, TEXT, TEXT, TIMESTAMP WITH TIME ZONE, BOOLEAN) TO authenticated;
