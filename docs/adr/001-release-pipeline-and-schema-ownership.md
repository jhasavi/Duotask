# ADR-001: Make `main` safe to deploy, and give migrations one owner

**Status:** Proposed
**Date:** 2026-11-13
**Deciders:** Sanjeev Jha

## Context

DuoTask is Flutter (web in production) + Supabase (Postgres, Auth, Realtime,
edge functions) + Vercel, with Stripe for Premium. The app layering is sound:
screens and widgets never touch Supabase directly, services own all data
access, four Realtime channels are service-owned, privileged operations are
`SECURITY DEFINER` RPCs (13 of them), RLS is enabled on 9 tables.

The risk is not the app code. It is the release path:

1. **Merging to `main` deploys to production.** `deploy.yml` runs
   `supabase db push` and publishes the web bundle on every push to `main`.
2. **Production's migration history is unreconciled.** As of 2026-10-15 the
   remote history recorded none of the local migrations and held three with no
   local file; schema was changed by hand. Several features (tags, recurrence,
   timezone, push tokens) were never applied there.
3. **CI deploys have never succeeded.** The last run (2026-11-05) failed at the
   secrets preflight, so the pipeline is untested end to end.
4. **No staging environment.** The live-backend integration suite has not run
   in CI; 5+ integration tests, including the new delete-account cases, are
   written but unexecuted against hosted Supabase.
5. **Migration sources are scattered.** `supabase/migrations/` (authoritative),
   a legacy top-level `migrations/`, and `supabase/schema.sql`. Migrations are
   also edited in place after commit (20261113000001 was), which silently does
   nothing on any database that already applied it.
6. **Two deploy paths.** `build/web` is committed *and* CI builds from source.

## Decision

Treat "first green CI deploy" as the next milestone, ahead of features:

- Create a staging Supabase project; point integration tests and a staging
  deploy at it.
- Reconcile production history (`migration list`, fetch the three remote-only
  files, `migration repair` only what is truly applied) **before** any merge
  that triggers `db push`.
- Migrations are forward-only. Never edit one that has left a feature branch;
  add a new file.
- One migration directory: `supabase/migrations/`. Retire `migrations/` and
  generate `schema.sql` from it or delete it.
- Stop committing `build/web` after the first green CI deploy.

## Options Considered

### A: Reconcile + staging, then merge (chosen)
| Dimension | Assessment |
|-----------|------------|
| Complexity | Medium, about a day of owner work |
| Cost | A second free/low-tier Supabase project |
| Risk | Lowest: `db push` first runs where mistakes are cheap |

**Pros:** exercises the real pipeline; unblocks the integration suite.
**Cons:** delays merging the launch-readiness PR.

### B: Merge now, let CI fail at preflight
Safe only while secrets are missing. The moment they are added, the first
`db push` hits an unreconciled production. Rejected as a standing state.

### C: Remove auto-deploy, deploy by hand
Reintroduces the five-week stale-bundle failure that `deploy.yml` was written
to prevent. Rejected.

## Trade-off Analysis

A costs a day now and removes the only unrecoverable failure mode in the
project (a bad migration against live user data). B and C trade that away for
speed.

## Other findings (not decisions yet)

| # | Finding | Suggested action |
|---|---------|------------------|
| 1 | `delete_my_account` verifies passwords by `crypt()` against `auth.users.encrypted_password`: couples to Supabase internals, and gives an unthrottled password oracle to any valid session. | **Done 2026-11-13:** throttled to 5 wrong passwords per 15 min (`20261113000002`). Still coupled to `auth.users`; acceptable. |
| 2 | Premium state lives in `users.is_premium/premium_until` *and* `billing_customers.subscription_status`; the delete guard has to check both. | Pick one source of truth (the webhook-written table) and derive the other. |
| 3 | `auth_service.dart` (788 lines) and `task_service.dart` (659) are the only large units. | Leave until a feature forces a split. |
| 4 | No offline queue; web-only production; push needs a Firebase project. | Roadmap items, after the pipeline milestone. |

## Consequences

- Easier: confident deploys, trustworthy integration tests, one place to look
  for schema.
- Harder: migrations can no longer be quietly amended.
- Revisit: whether staging should be a Supabase branch rather than a project.

## Action Items

1. [ ] Rotate leaked credentials (`docs/CREDENTIAL_ROTATION.md`), owner action.
2. [ ] Create staging project; `supabase db push` there; confirm all migrations apply.
3. [ ] Point integration secrets at staging; get Live-backend tests green in CI.
4. [x] Reconcile production history. As of 2026-11-13 `migration list` shows
       the six pre-August migrations applied remotely, no remote-only entries,
       and 13 pending (`20260828000001` onwards).
5. [ ] Add the six deploy secrets; confirm the preflight passes.
6. [ ] Merge PR #11; watch *Apply database migrations*; run the smoke test.
7. [x] `20261113000002` drops both `delete_my_account` overloads and recreates
       the guarded, throttled version, so any database that ran an earlier
       copy of `20261113000001` ends up correct.
8. [~] `migrations/` and `schema.sql` removed 2026-11-13. Still to do: stop
       committing `build/web` after the first green CI deploy.
9. [x] Finding 1 fixed (see above).
