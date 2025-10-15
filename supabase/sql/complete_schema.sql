-- Complete DuoTask Database Schema

-- Users table
CREATE TABLE IF NOT EXISTS public.usr (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL DEFAULT 'User',
    pair_code TEXT UNIQUE,
    paired_with UUID REFERENCES public.usr(id),
    email_confirmed BOOLEAN DEFAULT FALSE,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tasks table
CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'unclaimed' CHECK (status IN ('unclaimed', 'claimed', 'done')),
    owner_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
    claimed_by UUID REFERENCES public.usr(id) ON DELETE SET NULL,
    pair_id UUID REFERENCES public.usr(id) ON DELETE CASCADE,
    repeat_type TEXT NOT NULL DEFAULT 'none' CHECK (repeat_type IN ('none', 'daily', 'weekly', 'monthly', 'yearly')),
    due_date TIMESTAMP WITH TIME ZONE,
    urgent BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Pair codes table
CREATE TABLE IF NOT EXISTS public.pair_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Pair requests table
CREATE TABLE IF NOT EXISTS public.pair_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
    to_user_id UUID NOT NULL REFERENCES public.usr(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_usr_email ON public.usr(email);
CREATE INDEX IF NOT EXISTS idx_usr_pair_code ON public.usr(pair_code);
CREATE INDEX IF NOT EXISTS idx_usr_paired_with ON public.usr(paired_with);
CREATE INDEX IF NOT EXISTS idx_tasks_owner_id ON public.tasks(owner_id);
CREATE INDEX IF NOT EXISTS idx_tasks_claimed_by ON public.tasks(claimed_by);
CREATE INDEX IF NOT EXISTS idx_tasks_pair_id ON public.tasks(pair_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks(status);
CREATE INDEX IF NOT EXISTS idx_pair_codes_user_id ON public.pair_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_pair_codes_code ON public.pair_codes(code);
CREATE INDEX IF NOT EXISTS idx_pair_requests_from_user_id ON public.pair_requests(from_user_id);
CREATE INDEX IF NOT EXISTS idx_pair_requests_to_user_id ON public.pair_requests(to_user_id);
CREATE INDEX IF NOT EXISTS idx_pair_requests_status ON public.pair_requests(status);

-- Row Level Security (RLS) policies
ALTER TABLE public.usr ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pair_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pair_requests ENABLE ROW LEVEL SECURITY;

-- Users can read their own data and their partner's data
CREATE POLICY "Users can read own data" ON public.usr
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can read partner data" ON public.usr
    FOR SELECT USING (
        auth.uid() = paired_with OR 
        paired_with = auth.uid()
    );

-- Users can update their own data
CREATE POLICY "Users can update own data" ON public.usr
    FOR UPDATE USING (auth.uid() = id);

-- Users can insert their own data
CREATE POLICY "Users can insert own data" ON public.usr
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Tasks policies
CREATE POLICY "Users can read own tasks" ON public.tasks
    FOR SELECT USING (auth.uid() = owner_id);

CREATE POLICY "Users can read partner tasks" ON public.tasks
    FOR SELECT USING (
        auth.uid() = claimed_by OR 
        pair_id = auth.uid() OR
        (pair_id IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.usr 
            WHERE id = auth.uid() AND paired_with = tasks.owner_id
        ))
    );

CREATE POLICY "Users can insert own tasks" ON public.tasks
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Users can update own tasks" ON public.tasks
    FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "Users can update claimed tasks" ON public.tasks
    FOR UPDATE USING (auth.uid() = claimed_by);

CREATE POLICY "Users can delete own tasks" ON public.tasks
    FOR DELETE USING (auth.uid() = owner_id);

-- Pair codes policies
CREATE POLICY "Users can read own pair codes" ON public.pair_codes
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own pair codes" ON public.pair_codes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own pair codes" ON public.pair_codes
    FOR UPDATE USING (auth.uid() = user_id);

-- Pair requests policies
CREATE POLICY "Users can read own pair requests" ON public.pair_requests
    FOR SELECT USING (
        auth.uid() = from_user_id OR 
        auth.uid() = to_user_id
    );

CREATE POLICY "Users can insert pair requests" ON public.pair_requests
    FOR INSERT WITH CHECK (auth.uid() = from_user_id);

CREATE POLICY "Users can update pair requests" ON public.pair_requests
    FOR UPDATE USING (auth.uid() = to_user_id);

-- Functions
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_usr_updated_at BEFORE UPDATE ON public.usr
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON public.tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pair_requests_updated_at BEFORE UPDATE ON public.pair_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
