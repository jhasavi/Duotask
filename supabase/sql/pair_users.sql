-- Create atomic pairing RPC
-- Usage: select pair_users(p_user_id := 'uuid1', p_partner_id := 'uuid2');
-- Ensures both users exist, are not the same, neither is already paired, and updates both in a transaction.

create or replace function public.pair_users(p_user_id uuid, p_partner_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null or p_partner_id is null then
    raise exception 'User IDs must not be null';
  end if;
  if p_user_id = p_partner_id then
    raise exception 'Cannot pair with yourself';
  end if;

  perform 1 from public.usr where id = p_user_id;
  if not found then
    raise exception 'User % not found', p_user_id;
  end if;
  perform 1 from public.usr where id = p_partner_id;
  if not found then
    raise exception 'Partner % not found', p_partner_id;
  end if;

  -- Check neither is already paired
  if exists (select 1 from public.usr where id = p_user_id and paired_with is not null) then
    raise exception 'User % is already paired', p_user_id;
  end if;
  if exists (select 1 from public.usr where id = p_partner_id and paired_with is not null) then
    raise exception 'Partner % is already paired', p_partner_id;
  end if;

  -- Transactional update of both records
  update public.usr set paired_with = p_partner_id where id = p_user_id;
  update public.usr set paired_with = p_user_id where id = p_partner_id;

  return;
end;
$$;

-- Optional: grant execute to authenticated users
grant execute on function public.pair_users(uuid, uuid) to authenticated;
