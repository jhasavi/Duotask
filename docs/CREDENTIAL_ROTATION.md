# Credential rotation runbook

Four credentials were exposed and must be replaced. They are out of the
working tree but remain in git history, so **removing them changed nothing —
rotation is the only fix.**

Good news: every consumer already reads its credential from the environment,
so rotating requires no code changes. You are updating configuration in four
dashboards.

Work top to bottom. Each section says what to revoke, where the new value
goes, and how to confirm it worked.

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

**Revoke and replace**

1. Supabase Dashboard → Project Settings → **API Keys**
2. Locate the `service_role` secret → **Rotate** (or in newer projects,
   revoke the legacy key and issue a new secret key)
3. Copy the new value

> Rotating JWT-based keys may briefly interrupt clients using the old key.
> Nothing in the Flutter app uses `service_role` — only CI and edge functions
> do — so user-facing impact should be none.

**Where it goes**

- GitHub → repository → Settings → Secrets and variables → Actions →
  `SUPABASE_TEST_SERVICE_ROLE_KEY` (use your **test** project's key here, not
  production's)
- Anywhere else you kept a copy — remove those copies rather than updating them

**Verify**

Once the test project exists, the `integration.yml` workflow run is the check.

**Also rotate the anon key?** Not necessary. The anon key is a public,
client-side credential by design — it ships in the web bundle and is protected
by row-level security, not secrecy. Rotating it forces a rebuild for no
security benefit.

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

## 5. Confirm the leak is closed

The exposed file is still being served right now. After you deploy the
rebuilt bundle:

```bash
scripts/smoke_test.sh https://duotask.namasteneedham.com
```

It currently **fails** on `/assets/.env`. It must pass before you consider
this closed.

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
- [ ] Supabase `service_role` key rotated
- [ ] Vercel token rotated
- [ ] Rebuilt bundle deployed
- [ ] `scripts/smoke_test.sh` passes against production
