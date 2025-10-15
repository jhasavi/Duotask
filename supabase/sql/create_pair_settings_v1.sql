-- pair_settings: quiet hours and preferences per pair
create table if not exists public.pair_settings (
  pair_id uuid primary key,
  quiet_start time with time zone,
  quiet_end time with time zone,
  nudge_prefs jsonb default '{}'::jsonb,
  scene_defaults jsonb default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

alter table public.pair_settings enable row level security;

create policy if not exists select_pair_settings_for_pair
on public.pair_settings for select
using (exists (
  select 1 from public.usr u where u.id = auth.uid() and (pair_id = u.id or pair_id = u.paired_with)
));

create policy if not exists upsert_pair_settings_for_pair
on public.pair_settings for all
using (exists (
  select 1 from public.usr u where u.id = auth.uid() and (pair_id = u.id or pair_id = u.paired_with)
))
with check (exists (
  select 1 from public.usr u where u.id = auth.uid() and (pair_id = u.id or pair_id = u.paired_with)
));
