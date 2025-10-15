-- Weekly parity indicator source: tasks completed per owner per pair per week
-- Uses status = 'done' from public.tasks
create or replace view public.pair_weekly_task_stats as
select
  t.pair_id,
  date_trunc('week', coalesce(t.last_completed, t.updated_at))::date as week_start,
  t.owner_id,
  count(*)::int as done_count
from public.tasks t
where t.status = 'done'
group by 1,2,3;

-- Optional helper view to pivot counts by owner within a pair-week can be done app-side.
-- Indexes on base table already recommended in create_indexes_v1.sql.
