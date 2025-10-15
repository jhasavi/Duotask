-- Cancel an outgoing pairing request from p_user_id to any recipient
create or replace function public.cancel_outgoing_pair_request_v1(p_user_id uuid)
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
  where pair_status = 'pending' and pair_request_from = p_user_id;
end;
$$;

grant execute on function public.cancel_outgoing_pair_request_v1(uuid) to authenticated;
