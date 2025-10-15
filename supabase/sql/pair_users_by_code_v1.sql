-- Canonical, non-overloaded RPC name to avoid PostgREST ambiguity
-- Usage: select public.pair_users_by_code_v1(p_user_id := 'uuid', p_partner_code := 'CODE');

create or replace function public.pair_users_by_code_v1(p_user_id uuid, p_partner_code text)
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

  select id into partner_id
  from public.usr
  where upper(pair_code) = upper(p_partner_code)
    and id <> p_user_id
  limit 1;

  if partner_id is null then
    raise exception 'No user found with that code';
  end if;

  perform public.pair_users(p_user_id := p_user_id, p_partner_id := partner_id);
end;
$$;

grant execute on function public.pair_users_by_code_v1(uuid, text) to authenticated;
