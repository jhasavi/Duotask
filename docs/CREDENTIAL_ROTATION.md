# Credential rotation runbook

Four credentials were exposed and must be replaced. They are out of the
working tree but remain in git history, so **removing them changed nothing —
rotation is the only fix.**

*Status as of 2026-10-15: none of the four has been rotated. The public
`/assets/.env` leak itself is closed (verified 2026-09-16).*

## Do-it-now checklist (≈45 minutes, in this order)

The order matters: revoke the most dangerous credential first, and do the
Supabase rotation last because it is the only one with user-visible side
effects (it changes the anon key, and the web app must be rebuilt with it).

1. [ ] **Look for misuse first** (5 min) — §0 below. Screenshot anything odd.
2. [ ] **Resend** (5 min) — delete key `re_jR6ucccW_…`, create a
       *Sending access* key, then:
       `supabase secrets set RESEND_API_KEY=<new> --project-ref <ref>` — §1
3. [ ] **Discord** (2 min) — Developer Portal → DuoTask → Bot → *Reset Token*.
       The bot isn't deployed anywhere; if you don't plan to run it, delete
       the application instead — §2
4. [ ] **Vercel** (3 min) — https://vercel.com/account/tokens → delete every
       token older than today → create one scoped to DuoTask → GitHub secret
       `VERCEL_TOKEN` — §4
5. [ ] **Supabase service_role** (15 min) — rotate, then update **every**
       place the anon key lives (GitHub secret `SUPABASE_ANON_KEY`, Vault
       secret `anon_key`, your local `.env`) and redeploy the web app — §3
6. [ ] **Verify** (5 min) — trigger the digest and a nudge, sign in on the
       web app, run `scripts/smoke_test.sh https://duotask.namasteneedham.com`
7. [ ] Tick the boxes in [PROJECT_STATUS.md](../PROJECT_STATUS.md) and the
       checklist at the bottom of this file.

> **Before you push anything:** `main` has local commits that are not on
> GitHub yet, starting with `338dac9` (adds
> `supabase/migrations/20261014000001_harden_rpc_permissions.sql`) and the
> monetization work after it, which adds three more migrations.
> `deploy.yml` runs `supabase db push` against **production** on every push
> to `main`, so pushing applies all of them immediately. Rotate first, apply
> the migrations to a staging project
> ([MONETIZATION.md](MONETIZATION.md#go-live)), then push.

---

## 0. Before you start (2 minutes)

Check whether the exposed keys were actually used by anyone.

- **Resend** → https://resend.com/emails — look for sends you don't recognise,
  especially to addresses that aren't your users.
- **Supabase** → Project → Logs → Auth Logs — look for sign-ups or admin API
  calls from unfamiliar IPs.
- **Discord** → Server Settings → Audit Log — look for unexpected bot actions.

Note anything suspicious before you rotate; the logs stay, but context helps.

---

## 1. Resend API key — **highest priority**

Exposed key begins `re_jR6ucccW_`. Anyone holding it can send email that
appears to come from you, which is a phishing and domain-reputation risk.

**Revoke and replace**

1. Go to https://resend.com/api-keys
2. Find the existing key → **⋯ → Delete**. Delete first; a leaked sending key
   is worth more to an attacker than a few minutes of digest downtime.
3. **Create API Key** → name it `duotask-production` → permission
   **Sending access** (not Full access) → copy the new value.

**Where it goes**

Supabase Edge Function secrets — this is the only consumer
(`supabase/functions/daily-email-digest/index.ts` reads
`Deno.env.get('RESEND_API_KEY')`).

```bash
supabase secrets set RESEND_API_KEY=re_your_new_key --project-ref <your-project-ref>
```

Or: Supabase Dashboard → Edge Functions → Manage secrets.

**Verify**

```bash
supabase functions invoke daily-email-digest --project-ref <your-project-ref>
```

Then check https://resend.com/emails for the send.

---

## 2. Discord bot token

Exposed token begins `MTQ0MDQwNjU2`. It grants full control of the bot
account — reading and posting in every server the bot has joined.

**Revoke and replace**

1. Go to https://discord.com/developers/applications
2. Select the DuoTask application → **Bot**
3. **Reset Token** → confirm. This invalidates the old token immediately.
4. Copy the new token.

**Where it goes**

Wherever `discord-bot/index.js` runs (`client.login(process.env.DISCORD_TOKEN)`).
Set `DISCORD_TOKEN` in that host's environment — your local `.env`, or the
hosting provider's config if it's deployed.

> The bot appears to be a side component and may not be running anywhere. Reset
> the token regardless: an unused-but-valid token is still a live credential.
> If you don't intend to run it, delete the application entirely.

**Verify**

Restart the bot; it should come online in your server. If you deleted the
application, confirm it no longer appears in the member list.

---

## 3. Supabase `service_role` key

This one bypasses **all** row-level security — it can read and write every
row in every table, and create or delete any user. It was committed in
`test/integration/signup_race_test.dart` on a pushed branch.

**Know this before you start:** the legacy `anon` and `service_role` keys
are both JWTs signed with the project's JWT secret. There is no way to
invalidate *only* the leaked `service_role` key — whichever route you take,
the **anon key changes too**, and existing user sessions may be signed out
once. That is acceptable at DuoTask's size; just do it in one sitting.

**Revoke and replace** (pick one route; check the dashboard wording, which
Supabase has been changing)

- *Route A, simplest:* Dashboard → Project Settings → **JWT Keys** (older
  projects: *API → JWT Settings*) → **Generate a new JWT secret / rotate**.
  Both legacy keys are reissued; copy the new `anon` key.
- *Route B, Supabase's newer model:* Project Settings → **API Keys** → create
  a *publishable* key and a *secret* key, switch every consumer listed below
  to them, then **disable the legacy JWT-based keys**. More work, but future
  secret-key leaks can be revoked individually.

**Where the new values go**

- [ ] GitHub → Settings → Secrets and variables → Actions → `SUPABASE_ANON_KEY`
- [ ] Supabase Vault secret `anon_key` (read by the email-digest cron job and
      the nudge-push trigger) — SQL editor:
      `select vault.update_secret((select id from vault.secrets where name = 'anon_key'), '<new anon key>');`
- [ ] Your local `.env` (`SUPABASE_ANON_KEY=`)
- [ ] `SUPABASE_TEST_SERVICE_ROLE_KEY` in GitHub secrets — use your **test**
      project's key, never production's
- [ ] Edge functions read `SUPABASE_SERVICE_ROLE_KEY` from the platform,
      which injects the current value — nothing to set, but redeploy them
      once so no warm instance holds the old value:
      `supabase functions deploy daily-email-digest send-nudge-push --project-ref <ref>`
      (and `stripe-webhook` once it exists)
- [ ] Rebuild and redeploy the web app so it ships the new anon key
      (`deploy.yml` → *Run workflow*, or `scripts/build_web.sh` + Vercel)
- [ ] Delete any other copy of the old keys (notes, password managers,
      shell history) rather than updating it

**Verify**

- Sign in on https://duotask.namasteneedham.com (a stale anon key shows up as
  401s on every request)
- Send yourself a nudge → push arrives (exercises Vault `anon_key`)
- `supabase functions invoke daily-email-digest --project-ref <ref>` → 200
- Once the test project exists, a green `integration.yml` run

---

## 4. Vercel token

A `VERCEL_OIDC_TOKEN` was committed in `build/web/.env.local`. OIDC tokens are
short-lived and this one has almost certainly expired, but rotate the
long-lived account token as a precaution.

**Revoke and replace**

1. https://vercel.com/account/tokens
2. Delete any token you don't recognise or that predates today
3. **Create Token** → scope it to the DuoTask project → copy

**Where it goes**

GitHub → Settings → Secrets and variables → Actions → `VERCEL_TOKEN`

**Verify**

The first successful `deploy.yml` run.

---

## 5. Confirm the leak is closed — *done 2026-09-16*

Production now serves a bundle with no `/assets/.env`, and
`scripts/smoke_test.sh https://duotask.namasteneedham.com` passes. Re-run it
after the redeploy in §3 as a regression check.

---

## 6. Optional: purge git history

Rotation makes the old values worthless, which is the real fix. Rewriting
history is cosmetic by comparison and carries real cost — it breaks every
existing clone and fork.

If you still want it:

```bash
pip install git-filter-repo
git filter-repo --path build/web/assets/.env --path build/web/.env.local --invert-paths
git push --force --all
```

Do this **only after** rotating. Rewriting history without rotating fixes
nothing, because copies may already exist.

---

## Checklist

- [ ] Reviewed Resend, Supabase auth, and Discord logs for misuse
- [ ] Resend key deleted and replaced; digest send verified
- [ ] Discord token reset (or application deleted)
- [ ] Vercel token rotated
- [ ] Supabase JWT keys rotated; new anon key in GitHub secrets, Vault and `.env`
- [ ] Edge functions redeployed; web app rebuilt and redeployed with the new anon key
- [x] `scripts/smoke_test.sh` passes against production (2026-09-16; re-run after the redeploy)
