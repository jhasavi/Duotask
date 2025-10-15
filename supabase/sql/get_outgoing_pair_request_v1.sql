-- Return info about an outgoing pending request for the given user
create or replace function public.get_outgoing_pair_request_v1(p_user_id uuid)
returns table(recipient_id uuid, recipient_email text, recipient_name text)
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    raise exception 'User id is required';
  end if;

  return query
  select u.id, u.email, u.name
  from public.usr u
  where u.pair_status = 'pending' and u.pair_request_from = p_user_id
  limit 1;
end;
$$;

grant execute on function public.get_outgoing_pair_request_v1(uuid) to authenticated;
