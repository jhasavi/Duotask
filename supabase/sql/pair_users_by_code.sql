-- Pair users by partner code (case-insensitive) via secure RPC
-- Usage: select pair_users_by_code(p_user_id := 'uuid1', p_partner_code := 'ABC12345');
-- Delegates to pair_users after resolving the partner by code.

create or replace function public.pair_users_by_code(p_user_id uuid, p_partner_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  partner_id uuid;
begin
  if p_user_id is null or p_partner_code is null or length(trim(p_partner_code)) = 0 then
    raise exception 'User id and partner code are required';
  end if;

  -- Find partner by code (case-insensitive), cannot be self
  select id into partner_id
  from public.usr
  where upper(pair_code) = upper(p_partner_code)
    and id <> p_user_id
  limit 1;

  if partner_id is null then
    raise exception 'No user found with that code';
  end if;

  -- Delegate to transactional function
  perform public.pair_users(p_user_id := p_user_id, p_partner_id := partner_id);

  return;
end;
$$;

grant execute on function public.pair_users_by_code(uuid, text) to authenticated;
