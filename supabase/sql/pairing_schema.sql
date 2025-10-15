-- Add pending/acceptance columns to usr
alter table public.usr add column if not exists pair_request_from uuid;
alter table public.usr add column if not exists pair_status text check (pair_status in ('pending','accepted'));
create index if not exists idx_usr_pair_request_from on public.usr(pair_request_from);
