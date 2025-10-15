-- task_messages: per-task micro-chat & nudges
create table if not exists public.task_messages (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  pair_id uuid not null,
  user_id uuid not null references public.usr(id) on delete cascade,
  type text not null check (type in ('text','nudge')),
  body text,
  created_at timestamptz not null default now()
);

-- Indexes
create index if not exists idx_task_messages_task on public.task_messages(task_id);
create index if not exists idx_task_messages_pair on public.task_messages(pair_id);
create index if not exists idx_task_messages_created on public.task_messages(created_at);

-- RLS
alter table public.task_messages enable row level security;

-- Helper policy predicate: current user is member of pair for this row
create policy if not exists select_task_messages_for_pair
on public.task_messages for select
using (exists (
  select 1 from public.usr u
  where u.id = auth.uid()
  and (pair_id = u.id or pair_id = u.paired_with)
));

create policy if not exists insert_task_messages_for_pair
on public.task_messages for insert
with check (exists (
  select 1 from public.usr u
  where u.id = auth.uid()
  and (pair_id = u.id or pair_id = u.paired_with)
));

create policy if not exists update_task_messages_for_pair
on public.task_messages for update
using (exists (
  select 1 from public.usr u
  where u.id = auth.uid()
  and (pair_id = u.id or pair_id = u.paired_with)
))
with check (exists (
  select 1 from public.usr u
  where u.id = auth.uid()
  and (pair_id = u.id or pair_id = u.paired_with)
));

create policy if not exists delete_task_messages_for_pair
on public.task_messages for delete
using (exists (
  select 1 from public.usr u
  where u.id = auth.uid()
  and (pair_id = u.id or pair_id = u.paired_with)
));
