-- task_handoffs: propose/accept/decline handoffs between pair members
create table if not exists public.task_handoffs (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references public.tasks(id) on delete cascade,
  pair_id uuid not null,
  from_user uuid not null references public.usr(id) on delete cascade,
  to_user uuid not null references public.usr(id) on delete cascade,
  proposed_at timestamptz not null default now(),
  accept_by timestamptz,
  status text not null check (status in ('proposed','accepted','declined','expired')) default 'proposed'
);

create index if not exists idx_task_handoffs_task on public.task_handoffs(task_id);
create index if not exists idx_task_handoffs_pair on public.task_handoffs(pair_id);
create index if not exists idx_task_handoffs_status on public.task_handoffs(status);

alter table public.task_handoffs enable row level security;

create policy if not exists select_task_handoffs_for_pair
on public.task_handoffs for select
using (exists (
  select 1 from public.usr u where u.id = auth.uid() and (pair_id = u.id or pair_id = u.paired_with)
));

create policy if not exists insert_task_handoffs_for_pair
on public.task_handoffs for insert
with check (exists (
  select 1 from public.usr u where u.id = auth.uid() and (pair_id = u.id or pair_id = u.paired_with)
));

create policy if not exists update_task_handoffs_for_pair
on public.task_handoffs for update
using (exists (
  select 1 from public.usr u where u.id = auth.uid() and (pair_id = u.id or pair_id = u.paired_with)
))
with check (exists (
  select 1 from public.usr u where u.id = auth.uid() and (pair_id = u.id or pair_id = u.paired_with)
));

create policy if not exists delete_task_handoffs_for_pair
on public.task_handoffs for delete
using (exists (
  select 1 from public.usr u where u.id = auth.uid() and (pair_id = u.id or pair_id = u.paired_with)
));
