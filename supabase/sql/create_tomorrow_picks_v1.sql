-- tomorrow_picks: nightly ritual selections (3 per person)
create table if not exists public.tomorrow_picks (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null,
  user_id uuid not null references public.usr(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete cascade,
  pick_date date not null, -- local user date for "tomorrow"
  created_at timestamptz not null default now(),
  unique (pair_id, user_id, task_id, pick_date)
);

create index if not exists idx_tomorrow_picks_pair_date on public.tomorrow_picks(pair_id, pick_date);

alter table public.tomorrow_picks enable row level security;

create policy if not exists select_tomorrow_picks_for_pair
on public.tomorrow_picks for select
using (exists (
  select 1 from public.usr u where u.id = auth.uid() and (pair_id = u.id or pair_id = u.paired_with)
));

create policy if not exists insert_tomorrow_picks_for_pair
on public.tomorrow_picks for insert
with check (exists (
  select 1 from public.usr u where u.id = auth.uid() and (pair_id = u.id or pair_id = u.paired_with)
));

create policy if not exists delete_tomorrow_picks_for_pair
on public.tomorrow_picks for delete
using (exists (
  select 1 from public.usr u where u.id = auth.uid() and (pair_id = u.id or pair_id = u.paired_with)
));
