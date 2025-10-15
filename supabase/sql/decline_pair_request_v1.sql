-- Decline a pending pairing request for the current user
create or replace function public.decline_pair_request_v1(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    raise exception 'User id is required';
  end if;

  update public.usr
  set pair_request_from = null,
      pair_status = null
  where id = p_user_id
    and pair_status = 'pending';
end;
$$;

grant execute on function public.decline_pair_request_v1(uuid) to authenticated;
