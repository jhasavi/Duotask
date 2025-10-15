-- Atomic unpair RPC
-- Usage: select unpair_users(p_user_id := 'uuid1');
-- Clears paired_with for both users if they are currently paired with each other.

create or replace function public.unpair_users(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_partner_id uuid;
begin
  if p_user_id is null then
    raise exception 'User ID must not be null';
  end if;

  select paired_with into v_partner_id from public.usr where id = p_user_id;
  if not found then
    raise exception 'User % not found', p_user_id;
  end if;

  if v_partner_id is null then
    -- already unpaired; nothing to do
    return;
  end if;

  -- Verify reciprocal pairing
  if not exists (select 1 from public.usr where id = v_partner_id and paired_with = p_user_id) then
    -- Inconsistent state; still force-clear both sides
    update public.usr set paired_with = null where id in (p_user_id, v_partner_id);
    return;
  end if;

  -- Clear both sides
  update public.usr set paired_with = null where id in (p_user_id, v_partner_id);

  return;
end;
$$;

grant execute on function public.unpair_users(uuid) to authenticated;
