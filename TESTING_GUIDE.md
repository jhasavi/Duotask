# Testing Guide

## The two suites

| Suite | Command | Backend | Runs in CI |
|---|---|---|---|
| Hermetic (unit + widget + model) | `flutter test --exclude-tags integration` | None | Every push and PR |
| Integration | `flutter test --tags integration` | Real Supabase **test** project | Push to `main`, nightly, manual |

`flutter test` must never touch a network backend. If you add a test that
needs one, tag it `integration`.

> This used to be untrue: `flutter test` connected to the **production**
> Supabase project and created and deleted real auth users on every run. That
> is why the split exists — do not undo it.

## Running the hermetic suite

```bash
flutter test --exclude-tags integration
```

80 tests, no configuration required. A bare `flutter test` is also safe: the
integration tests self-skip when credentials are absent. Use the explicit
`--exclude-tags` form in CI and scripts so the boundary does not depend on
whether a developer happens to have credentials exported.

> Exclusion is **not** configured as a tag-level `skip:` in `dart_test.yaml`.
> It was, and that skip applied even when the tag was explicitly selected with
> `--tags integration` — so the live-backend job reported "All tests skipped"
> and would have passed without ever running a single test. Keep exclusion on
> the command line.

## Running the integration suite

These create and delete real auth users. **Point them at a dedicated test
project, never production.**

```bash
export SUPABASE_TEST_URL=https://<test-project>.supabase.co
export SUPABASE_TEST_ANON_KEY=...
export SUPABASE_TEST_SERVICE_ROLE_KEY=...
flutter test --tags integration
```

Credentials are read by `test/support/integration_env.dart`, from either the
process environment or `--dart-define`. No key is ever written into a test
file.

See [docs/RELEASE.md](docs/RELEASE.md) for how to provision the test project.

### Running integration tests locally

You can run the whole suite against a local Supabase stack (Docker) instead
of a hosted test project. This first worked on 2026-10-16, and it found three
bugs that the stubbed-Postgres check had missed (see
`20261016000000_fix_fresh_project_schema_gaps.sql` and
`20261016000002_fix_cycle_task_status_permission_check.sql`).

Two local tweaks are needed. Make them in a **copy** of `supabase/`, so the
repo stays as it is:

- The cron migrations refuse to run without the Vault secrets, so add a
  migration that sorts first and creates them.
- Use Postgres 17 to match production. If the CLI wants an image you don't
  have, pin one you do have in `.temp/postgres-version`.

```bash
mkdir -p /tmp/duotask-local && cp -R supabase /tmp/duotask-local/
cd /tmp/duotask-local
cat > supabase/migrations/19990101000000_local_vault_stub.sql <<'SQL'
select vault.create_secret('http://127.0.0.1:54321', 'project_url');
select vault.create_secret('local-anon', 'anon_key');
SQL
sed -i '' 's/^major_version = 15/major_version = 17/' supabase/config.toml
supabase start -x studio,imgproxy,inbucket,edge-runtime,logflare,vector,supavisor,storage-api
eval "$(supabase status -o env | grep -E '^(API_URL|ANON_KEY|SERVICE_ROLE_KEY)=')"
cd -   # back to the repo
SUPABASE_TEST_URL=$API_URL SUPABASE_TEST_ANON_KEY=$ANON_KEY \
  SUPABASE_TEST_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY flutter test --tags integration
```

The keys `supabase status` prints are Supabase's fixed local demo keys, not
secrets. After changing a migration, copy it into the stack's `migrations/`
and run `supabase db reset --local`.

### What the integration suite covers

| Test | Replaces |
|---|---|
| `signup_race_test.dart` — first sign-in survives the auth-listener race | The "sign up two fresh accounts back to back and see if either gets bounced" manual check |
| `pairing_flow_test.dart` — two users pair via a code, both observe it | "Pair two users and verify bidirectional visibility" |
| `pairing_flow_test.dart` — a consumed code cannot be redeemed twice | (was never checked) |
| `pairing_flow_test.dart` — unpairing clears both sides | "Test unpair" |
| `pairing_flow_test.dart` — a group task is visible to the partner | "Create personal vs group tasks" |
| `rpc_permissions_test.dart` — `cycle_task_status` rejects outsiders and spoofed `user_uuid` | (was never checked) |
| `task_share_test.dart` — share links: owner-only, anon visibility, responses, revoke/expiry, claim and auto-pair | (new feature, [docs/SHARE_LINKS.md](docs/SHARE_LINKS.md)) |

## Static analysis

```bash
flutter analyze
```

**The tree is at zero analyzer issues and CI is fatal on all of them**,
including infos. Formatting is enforced too:

```bash
dart format --output=none --set-exit-if-changed lib test
```

Do not reintroduce `--no-fatal-warnings`. A suppressed "unused variable"
warning concealed a real security bug: the password-change dialog declared a
current-password controller it never rendered or verified.

## Release verification

`scripts/smoke_test.sh` exits `0` when the deployment is clean, `1` when a
check fails, and `2` when the deployment could not be inspected at all — for
example a Vercel preview behind Deployment Protection, which answers every
request with an SSO redirect. That third state exists because the secret
probes would otherwise report PASS without having looked at anything.

```bash
scripts/verify_bundle.sh          # no secrets in build/web
scripts/smoke_test.sh <url>       # deployed app loads, leaks nothing
```

Both run automatically in CI. See [SECURITY.md](SECURITY.md).

## What is still manual

Nothing is a release gate, but these are not automated:

- Visual/animation review of the bubble interface
- Push notification delivery on physical iOS/Android devices
- Google OAuth end-to-end (requires a real Google account)
- Daily email digest rendering (the cron job is scheduled, not asserted)
