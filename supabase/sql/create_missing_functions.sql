-- Create missing database functions for DuoTask app

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
    partner_name = EXCLUDED.partner_name;
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

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION public.get_frequent_partners(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tasks_for_pairing(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_partner_history(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_task_pairing_history(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_partner_history_on_unpair(UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_task_pairing_history_on_unpair(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unpair_users_v1(UUID) TO authenticated;
