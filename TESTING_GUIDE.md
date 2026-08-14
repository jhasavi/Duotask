# Testing Guide

## The two suites

| Suite | Command | Backend | Runs in CI |
|---|---|---|---|
| Hermetic (unit + widget + model) | `flutter test` | None | Every push and PR |
| Integration | `flutter test --tags integration` | Real Supabase **test** project | Push to `main`, nightly, manual |

`flutter test` must never touch a network backend. If you add a test that
needs one, tag it `integration`.

> This used to be untrue: `flutter test` connected to the **production**
> Supabase project and created and deleted real auth users on every run. That
> is why the split exists — do not undo it.

## Running the hermetic suite

```bash
flutter test
```

76 tests, no configuration required. Integration tests self-skip with an
explanatory message when credentials are absent.

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

### What the integration suite covers

| Test | Replaces |
|---|---|
| `signup_race_test.dart` — first sign-in survives the auth-listener race | The "sign up two fresh accounts back to back and see if either gets bounced" manual check |
| `pairing_flow_test.dart` — two users pair via a code, both observe it | "Pair two users and verify bidirectional visibility" |
| `pairing_flow_test.dart` — a consumed code cannot be redeemed twice | (was never checked) |
| `pairing_flow_test.dart` — unpairing clears both sides | "Test unpair" |
| `pairing_flow_test.dart` — a group task is visible to the partner | "Create personal vs group tasks" |

## Static analysis

```bash
flutter analyze
```

**Errors and warnings must be zero.** CI enforces this. Infos are currently
tolerated; there is a known backlog (see
[UNIMPLEMENTED_FEATURES.md](UNIMPLEMENTED_FEATURES.md)).

Do not reintroduce `--no-fatal-warnings`. A suppressed "unused variable"
warning concealed a real security bug: the password-change dialog declared a
current-password controller it never rendered or verified.

## Release verification

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
