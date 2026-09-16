# Release process

Releases are automated. Merging to `main` builds from that commit, applies
migrations, deploys, and smoke-tests the result. There is no manual build step
and no manual test checklist.

## What happens on merge to `main`

```
.github/workflows/ci.yml           analyze (fatal on warnings) → hermetic tests → build → bundle secret scan
.github/workflows/integration.yml  live-backend tests against the TEST project
.github/workflows/deploy.yml       preflight secret check → supabase db push → build with --dart-define → verify bundle → vercel deploy → smoke test
```

A failure at any stage stops the release.

`deploy.yml` starts with a **preflight** job that checks every secret it needs
and reports all of the missing ones at once, before any build runs. If you see
a "Deploy secrets missing" error, the job summary lists exactly which ones and
where to add them — the setup below is all it wants.

Note the two workflows behave differently when their secrets are absent, on
purpose:

| Workflow | Secrets missing | Why |
|---|---|---|
| `integration.yml` | Warns and **skips** (green) | A missing test project is a setup gap, not a code defect. The warning states the flows are unverified. |
| `deploy.yml` | **Fails** (red) | A deploy that cannot run means merged code is not reaching users. That should be loud — it is how a five-week-stale bundle went unnoticed. |

## Merge gates on `main`

Branch protection enforces these. They are the automated substitute for the
review that a single-maintainer repository can never get.

| Rule | Setting | Why |
|---|---|---|
| Pull request required | yes, **0 approvals** | `main` cannot be pushed to directly. The approval count is 0 because the sole collaborator is also always the author, and GitHub forbids self-approval — a non-zero count is a gate nobody can ever satisfy, not a safety measure. |
| Required status checks | `Analyze, test, build`, `Secret scan` | The real gate. Analysis (fatal on everything), 80 hermetic tests, the web build, and the tracked-file secret scan must all pass before anything reaches `main`. |
| Strict status checks | on | A branch must be up to date with `main` before merging, so a PR cannot be merged having been tested against a stale base. |
| Admins included | on | The rules apply to the owner too; there is no override button. |
| Force pushes / deletions | blocked | History on `main` cannot be rewritten or removed. |

Two checks are deliberately **not** required:

- **`Live-backend integration tests`** — it currently passes by skipping,
  because the test project does not exist. Requiring a check that is green
  without having run anything would be a gate in name only. Add it once the
  `SUPABASE_TEST_*` secrets are configured.
- **`Check deploy secrets` / `Apply database migrations` / `Build and deploy
  web`** — these run *after* a merge, on `main`. Requiring them would
  deadlock: they cannot pass until the deploy secrets exist, and no PR could
  merge in the meantime.

To require the integration suite later, once the test project is live:

```bash
gh api -X PATCH repos/<owner>/<repo>/branches/main/protection/required_status_checks \
  -F strict=true \
  -f 'contexts[]=Analyze, test, build' \
  -f 'contexts[]=Secret scan' \
  -f 'contexts[]=Live-backend integration tests'
```

## One-time setup

This is the only part that still needs a human, and it has **not been done
yet**. Until it is, `deploy.yml` will fail and deployment stays manual.

### 1. GitHub repository secrets

Settings → Secrets and variables → Actions:

| Secret | Where to get it |
|---|---|
| `SUPABASE_URL` | Supabase → Project Settings → API |
| `SUPABASE_ANON_KEY` | Supabase → Project Settings → API |
| `WEB_REDIRECT_URL` | Your production URL + OAuth callback path |
| `GOOGLE_WEB_CLIENT_ID` | Google Cloud console |
| `VERCEL_TOKEN` | Vercel → Account Settings → Tokens |
| `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID` | `.vercel/project.json` after `vercel link` |
| `SUPABASE_ACCESS_TOKEN` | Supabase → Account → Access Tokens |
| `SUPABASE_PROJECT_REF` | Supabase project ref (the subdomain) |
| `SUPABASE_DB_PASSWORD` | Supabase → Project Settings → Database |

### 2. A dedicated Supabase test project

Integration tests create and delete real auth users. **Do not point them at
production.** Create a second, empty Supabase project, then:

```bash
supabase link --project-ref <test-project-ref>
supabase db push
```

The baseline migration provisions it into the same shape as production. Then
add these secrets:

| Secret |
|---|
| `SUPABASE_TEST_URL` |
| `SUPABASE_TEST_ANON_KEY` |
| `SUPABASE_TEST_SERVICE_ROLE_KEY` |

### 3. Stop committing `build/web`

`build/web` is currently still tracked, because Vercel is configured to serve
the committed directory (`vercel.json` has `buildCommand: null`). Once
`deploy.yml` is running and green, this should be reversed — otherwise the
committed bundle can drift from source again, which is exactly what caused the
sign-up fix to sit undeployed for five weeks:

```bash
git rm -r --cached build/web
echo 'build/' >> .gitignore   # replacing the "!/build/web/" exception
```

Do this **after** confirming a CI deploy succeeds, not before.

## Manual deploy (fallback until the above is done)

```bash
scripts/build_web.sh
```

Then deploy `build/web`. Never run a bare `flutter build web` — it can bundle
a `.env` into the output. `scripts/build_web.sh` injects config via
`--dart-define`, strips any env file, and runs the secret scan.

Afterwards, verify:

```bash
scripts/smoke_test.sh https://your-domain.example.com
```

## Verifying a release

`scripts/smoke_test.sh` checks that the app shell and bundle load, that no
`.env` is publicly readable, and that no secret-shaped strings are served. It
exits non-zero on any failure and runs automatically after a CI deploy.
