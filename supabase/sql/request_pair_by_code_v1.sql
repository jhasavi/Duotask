-- Create a pending pairing request by partner code
-- Sets recipient's pair_request_from and pair_status='pending'
-- Returns recipient metadata for email
create or replace function public.request_pair_by_code_v1(p_user_id uuid, p_partner_code text)
returns table(recipient_id uuid, recipient_email text, recipient_name text)
language plpgsql
security definer
set search_path = public
as $$
declare
  partner_id uuid;
  already_paired boolean;
  partner_paired boolean;
  r_email text;
  r_name text;
begin
  if p_user_id is null or p_partner_code is null or length(trim(p_partner_code)) = 0 then
    raise exception 'User id and partner code are required';
  end if;

  -- Resolve partner by code (case-insensitive)
  select id into partner_id
  from public.usr
  where upper(pair_code) = upper(p_partner_code)
    and id <> p_user_id
  limit 1;

  if partner_id is null then
    raise exception 'No user found with that code';
  end if;

  -- Check either already paired
  select paired_with is not null into already_paired from public.usr where id = p_user_id;
  select paired_with is not null into partner_paired from public.usr where id = partner_id;
  if already_paired then
    raise exception 'You are already paired';
  end if;
  if partner_paired then
    raise exception 'Partner is already paired';
  end if;

  -- Ensure no existing pending request for partner
  if exists (
    select 1 from public.usr where id = partner_id and pair_status = 'pending'
  ) then
    raise exception 'Partner already has a pending request';
  end if;

  -- Set pending request on partner
  update public.usr
  set pair_request_from = p_user_id,
      pair_status = 'pending'
  where id = partner_id;

  -- Return recipient info for email
  select u.id, u.email, u.name into recipient_id, recipient_email, recipient_name
  from public.usr u where u.id = partner_id;

  return next;
end;
$$;

grant execute on function public.request_pair_by_code_v1(uuid, text) to authenticated;
