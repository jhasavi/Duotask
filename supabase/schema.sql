-- DuoTask Database Schema
-- Execute this in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  display_name TEXT,
  avatar_url TEXT,
  pairing_code TEXT UNIQUE,
  paired_with_id UUID REFERENCES users(id) ON DELETE SET NULL,
  paired_with_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tasks table
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  created_by_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assigned_to_id UUID REFERENCES users(id) ON DELETE SET NULL,
  claimed_by_id UUID REFERENCES users(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'unclaimed' CHECK (status IN ('unclaimed', 'claimed', 'completed')),
  priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal', 'urgent')),
  recurrence TEXT NOT NULL DEFAULT 'none' CHECK (recurrence IN ('none', 'daily', 'weekly')),
  due_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  is_personal BOOLEAN DEFAULT FALSE,
  visibility TEXT NOT NULL DEFAULT 'personal' CHECK (visibility IN ('personal', 'group')),
  pair_id UUID REFERENCES pairings(id) ON DELETE SET NULL
);

-- Pairings table
CREATE TABLE IF NOT EXISTS pairings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  recipient_id UUID REFERENCES users(id) ON DELETE CASCADE,
  pairing_code TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'rejected', 'cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_users_pairing_code ON users(pairing_code);
CREATE INDEX IF NOT EXISTS idx_users_paired_with ON users(paired_with_id);
CREATE INDEX IF NOT EXISTS idx_tasks_created_by ON tasks(created_by_id);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to ON tasks(assigned_to_id);
CREATE INDEX IF NOT EXISTS idx_tasks_claimed_by ON tasks(claimed_by_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date);
CREATE INDEX IF NOT EXISTS idx_tasks_pair_id ON tasks(pair_id);
CREATE INDEX IF NOT EXISTS idx_tasks_visibility ON tasks(visibility);
CREATE INDEX IF NOT EXISTS idx_pairings_code ON pairings(pairing_code);
CREATE INDEX IF NOT EXISTS idx_pairings_requester ON pairings(requester_id);
CREATE INDEX IF NOT EXISTS idx_pairings_recipient ON pairings(recipient_id);

-- Updated at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_tasks_updated_at ON tasks;
CREATE TRIGGER update_tasks_updated_at
  BEFORE UPDATE ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_pairings_updated_at ON pairings;
CREATE TRIGGER update_pairings_updated_at
  BEFORE UPDATE ON pairings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Row Level Security (RLS) Policies

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE pairings ENABLE ROW LEVEL SECURITY;

-- Users policies
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
CREATE POLICY "Users can view their own profile"
  ON users FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can view their partner's profile" ON users;
CREATE POLICY "Users can view their partner's profile"
  ON users FOR SELECT
  USING (auth.uid() = paired_with_id);

DROP POLICY IF EXISTS "Users can update their own profile" ON users;
CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert their own profile" ON users;
CREATE POLICY "Users can insert their own profile"
  ON users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Tasks policies
DROP POLICY IF EXISTS "Users can view their own tasks" ON tasks;
CREATE POLICY "Users can view their own tasks"
  ON tasks FOR SELECT
  USING (
    -- Personal tasks: only creator can see
    (visibility = 'personal' AND auth.uid() = created_by_id)
    OR
    -- Group tasks: both users in the pair can see
    (visibility = 'group' AND pair_id IN (
      SELECT id FROM pairings 
      WHERE status = 'active' 
      AND (requester_id = auth.uid() OR recipient_id = auth.uid())
    ))
    OR
    -- Backward compatibility: tasks assigned to or claimed by user
    auth.uid() = assigned_to_id OR
    auth.uid() = claimed_by_id
  );

DROP POLICY IF EXISTS "Users can create tasks" ON tasks;
CREATE POLICY "Users can create tasks"
  ON tasks FOR INSERT
  WITH CHECK (auth.uid() = created_by_id);

DROP POLICY IF EXISTS "Users can update their own tasks" ON tasks;
CREATE POLICY "Users can update their own tasks"
  ON tasks FOR UPDATE
  USING (
    -- Personal tasks: only creator can update
    (visibility = 'personal' AND auth.uid() = created_by_id)
    OR
    -- Group tasks: both users in the pair can update
    (visibility = 'group' AND pair_id IN (
      SELECT id FROM pairings 
      WHERE status = 'active' 
      AND (requester_id = auth.uid() OR recipient_id = auth.uid())
    ))
    OR
    -- Backward compatibility
    auth.uid() = assigned_to_id
  );

DROP POLICY IF EXISTS "Users can delete their own tasks" ON tasks;
CREATE POLICY "Users can delete their own tasks"
  ON tasks FOR DELETE
  USING (auth.uid() = created_by_id);

-- Pairings policies
DROP POLICY IF EXISTS "Users can view pairings they're involved in" ON pairings;
DROP POLICY IF EXISTS "Users can view their pairings or search pending codes" ON pairings;
CREATE POLICY "Users can view their pairings or search pending codes"
  ON pairings FOR SELECT
  USING (
    -- User is involved in this pairing
    (auth.uid() = requester_id OR auth.uid() = recipient_id)
    OR
    -- OR it's a pending pairing (allows searching by code)
    (status = 'pending')
  );

DROP POLICY IF EXISTS "Users can create pairing requests" ON pairings;
CREATE POLICY "Users can create pairing requests"
  ON pairings FOR INSERT
  WITH CHECK (auth.uid() = requester_id);

DROP POLICY IF EXISTS "Users can update pairings they're involved in" ON pairings;
CREATE POLICY "Users can update pairings they're involved in"
  ON pairings FOR UPDATE
  USING (auth.uid() = requester_id OR auth.uid() = recipient_id);

-- Function to generate unique pairing code
CREATE OR REPLACE FUNCTION generate_pairing_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  result TEXT := '';
  i INTEGER;
BEGIN
  FOR i IN 1..8 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::INTEGER, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Function to create user profile on signup
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO users (id, email, display_name, pairing_code)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email),
    generate_pairing_code()
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create user profile on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_profile();

-- Function to sync pairing status
CREATE OR REPLACE FUNCTION sync_pairing_status()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'active' AND OLD.status != 'active' THEN
    -- Update both users' paired_with_id
    UPDATE users SET 
      paired_with_id = NEW.recipient_id,
      paired_with_name = (SELECT display_name FROM users WHERE id = NEW.recipient_id)
    WHERE id = NEW.requester_id;
    
    UPDATE users SET 
      paired_with_id = NEW.requester_id,
      paired_with_name = (SELECT display_name FROM users WHERE id = NEW.requester_id)
    WHERE id = NEW.recipient_id;
    
    -- Set accepted_at timestamp
    NEW.accepted_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to sync pairing status
DROP TRIGGER IF EXISTS on_pairing_status_change ON pairings;
CREATE TRIGGER on_pairing_status_change
  BEFORE UPDATE ON pairings
  FOR EACH ROW
  EXECUTE FUNCTION sync_pairing_status();

-- Function to cycle task status atomically (prevents race conditions)
CREATE OR REPLACE FUNCTION cycle_task_status(
  task_uuid UUID,
  user_uuid UUID
)
RETURNS TABLE (
  id UUID,
  status TEXT,
  claimed_by_id UUID,
  claimed_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
) AS $$
DECLARE
  current_status TEXT;
  new_status TEXT;
  new_claimed_by UUID;
  new_claimed_at TIMESTAMPTZ;
  new_completed_at TIMESTAMPTZ;
BEGIN
  -- Lock the row for update
  SELECT tasks.status INTO current_status
  FROM tasks
  WHERE tasks.id = task_uuid
  FOR UPDATE;

  -- Determine new status based on current status
  CASE current_status
    WHEN 'unclaimed' THEN
      new_status := 'claimed';
      new_claimed_by := user_uuid;
      new_claimed_at := NOW();
      new_completed_at := NULL;
    WHEN 'claimed' THEN
      new_status := 'completed';
      new_claimed_by := (SELECT tasks.claimed_by_id FROM tasks WHERE tasks.id = task_uuid);
      new_claimed_at := (SELECT tasks.claimed_at FROM tasks WHERE tasks.id = task_uuid);
      new_completed_at := NOW();
    WHEN 'completed' THEN
      new_status := 'unclaimed';
      new_claimed_by := NULL;
      new_claimed_at := NULL;
      new_completed_at := NULL;
    ELSE
      RAISE EXCEPTION 'Invalid task status: %', current_status;
  END CASE;

  -- Update and return the task
  RETURN QUERY
  UPDATE tasks
  SET 
    status = new_status,
    claimed_by_id = new_claimed_by,
    claimed_at = new_claimed_at,
    completed_at = new_completed_at,
    updated_at = NOW()
  WHERE tasks.id = task_uuid
  RETURNING tasks.id, tasks.status::TEXT, tasks.claimed_by_id, 
            tasks.claimed_at, tasks.completed_at, tasks.updated_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Enable realtime for all tables
ALTER PUBLICATION supabase_realtime ADD TABLE users;
ALTER PUBLICATION supabase_realtime ADD TABLE tasks;
ALTER PUBLICATION supabase_realtime ADD TABLE pairings;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
