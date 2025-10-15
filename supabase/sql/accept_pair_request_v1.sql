-- Accept a pending pairing request for the current user
create or replace function public.accept_pair_request_v1(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_id uuid;
begin
  if p_user_id is null then
    raise exception 'User id is required';
  end if;

  select pair_request_from into requester_id
  from public.usr
  where id = p_user_id and pair_status = 'pending'
  limit 1;

  if requester_id is null then
    raise exception 'No pending request to accept';
  end if;

  -- Perform actual pairing
  perform public.pair_users(p_user_id := p_user_id, p_partner_id := requester_id);

  -- Clear request state on both users
  update public.usr set pair_request_from = null, pair_status = null where id in (p_user_id, requester_id);
end;
$$;

grant execute on function public.accept_pair_request_v1(uuid) to authenticated;
