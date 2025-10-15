-- Helpful indexes for pairing and tasks
create index if not exists idx_usr_paired_with on public.usr(paired_with);
create index if not exists idx_tasks_pair on public.tasks(pair_id);
create index if not exists idx_tasks_owner on public.tasks(owner_id);
create index if not exists idx_tasks_last_completed on public.tasks(last_completed);
