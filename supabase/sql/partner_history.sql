-- Partner History Table
-- Tracks previous partnerships for frequent partners feature
CREATE TABLE IF NOT EXISTS public.partner_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
    partner_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
    partner_name TEXT NOT NULL,
    first_paired_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_paired_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    total_pairing_duration INTERVAL DEFAULT '0'::interval,
    pairing_count INTEGER DEFAULT 1,
    is_favorite BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure unique user-partner combinations
    UNIQUE(user_id, partner_id)
);

-- Index for efficient queries
CREATE INDEX IF NOT EXISTS idx_partner_history_user_id ON public.partner_history(user_id);
CREATE INDEX IF NOT EXISTS idx_partner_history_last_paired ON public.partner_history(last_paired_at DESC);
CREATE INDEX IF NOT EXISTS idx_partner_history_favorite ON public.partner_history(user_id, is_favorite);

-- Enable RLS
ALTER TABLE public.partner_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own partner history" ON public.partner_history
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own partner history" ON public.partner_history
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own partner history" ON public.partner_history
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own partner history" ON public.partner_history
    FOR DELETE USING (auth.uid() = user_id);

-- Function to add or update partner history
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
    INSERT INTO public.partner_history (
        user_id,
        partner_id,
        partner_name,
        first_paired_at,
        last_paired_at,
        pairing_count
    ) VALUES (
        p_user_id,
        p_partner_id,
        p_partner_name,
        NOW(),
        NOW(),
        1
    )
    ON CONFLICT (user_id, partner_id)
    DO UPDATE SET
        last_paired_at = NOW(),
        pairing_count = partner_history.pairing_count + 1,
        updated_at = NOW();
END;
$$;

-- Function to get frequent partners for a user
CREATE OR REPLACE FUNCTION public.get_frequent_partners(p_user_id UUID)
RETURNS TABLE(
    partner_id UUID,
    partner_name TEXT,
    last_paired_at TIMESTAMP WITH TIME ZONE,
    pairing_count INTEGER,
    is_favorite BOOLEAN
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
        ph.last_paired_at,
        ph.pairing_count,
        ph.is_favorite
    FROM public.partner_history ph
    WHERE ph.user_id = p_user_id
    ORDER BY 
        ph.is_favorite DESC,
        ph.last_paired_at DESC,
        ph.pairing_count DESC
    LIMIT 10;
END;
$$;

-- Function to toggle favorite status
CREATE OR REPLACE FUNCTION public.toggle_partner_favorite(
    p_user_id UUID,
    p_partner_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    current_favorite BOOLEAN;
BEGIN
    SELECT is_favorite INTO current_favorite
    FROM public.partner_history
    WHERE user_id = p_user_id AND partner_id = p_partner_id;
    
    IF current_favorite IS NULL THEN
        RETURN false;
    END IF;
    
    UPDATE public.partner_history
    SET 
        is_favorite = NOT current_favorite,
        updated_at = NOW()
    WHERE user_id = p_user_id AND partner_id = p_partner_id;
    
    RETURN NOT current_favorite;
END;
$$;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.partner_history TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_partner_history(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_frequent_partners(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_partner_favorite(UUID, UUID) TO authenticated;

-- Update existing pairing functions to track history
-- This will be called when users pair
CREATE OR REPLACE FUNCTION public.pair_users_with_history(
    p_user_id UUID,
    p_partner_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_name TEXT;
    partner_name TEXT;
BEGIN
    -- Get names for history tracking
    SELECT name INTO user_name FROM public.usr WHERE id = p_user_id;
    SELECT name INTO partner_name FROM public.usr WHERE id = p_partner_id;
    
    -- Pair the users
    PERFORM public.pair_users(p_user_id, p_partner_id);
    
    -- Add to partner history for both users
    PERFORM public.add_partner_history(p_user_id, p_partner_id, partner_name);
    PERFORM public.add_partner_history(p_partner_id, p_user_id, user_name);
END;
$$;

GRANT EXECUTE ON FUNCTION public.pair_users_with_history(UUID, UUID) TO authenticated;
