# Top 10 to be release ready

*Written 2026-11-19. A ranked short list for the go / no-go call. Detail for each
item is in [NEXT_ACTIONS.md](NEXT_ACTIONS.md). Code state: `flutter analyze`
clean, tests pass on `feat/launch-readiness` (PR 11) and `feat/timezone-picker`.*

**Go if items 1 to 7 are done. Items 8 to 10 can follow within days.**

| # | Item | Why it matters | Who |
|---|------|----------------|-----|
| 1 | **Close the Supabase key leak**: move to the new keys, then disable the legacy keys and confirm the old `service_role` key returns 401 | The leaked key still works today. Biggest risk. | You + Claude |
| 2 | **Buy `evenhalf.com` and `evenhalf.app`**, run the USPTO search | Someone else can take them. Blocks all marketing. | You |
| 3 | **Add the six GitHub Actions secrets** (`SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD`, `VERCEL_TOKEN`, `VERCEL_ORG_ID`, `VERCEL_PROJECT_ID`) | The merge pipeline cannot deploy without them. | You |
| 4 | **Run all migrations on staging** (new project or local Docker) and run `flutter test test/integration` | The 17 November migrations have only run on the CI test project. | You + Claude |
| 5 | **Check production before the merge**: cron jobs, Vault secrets `project_url` and `anon_key`, 17 migrations still unapplied | Merging PR 11 runs `supabase db push` on production. | Claude |
| 6 | **Merge PR 11, watch *Apply database migrations*, run `scripts/smoke_test.sh`** | This is the release itself. Fixes the missing `tasks.tags` column. | You + Claude |
| 7 | **Support and privacy mail**: Cloudflare Email Routing for `support@` and `privacy@evenhalf.app`, point the domain at Vercel, switch the app URL in one commit | The legal pages already promise these addresses. | You + Claude |
| 8 | **Decide on `feat/timezone-picker`**: 1 commit ahead of `main` after the rebase (invite-link pairing), tests pass. Merge it after PR 11 or fold it in | Not blocking, but it is finished work. | You |
| 9 | **Legal and console cleanup**: legal review of the Terms (MA jurisdiction, 14-day refund, arbitration), reconcile the two sets of legal pages, update Supabase, Google OAuth and Resend consoles for the new name and domain, claim social handles | Needed before Stripe live mode and store listings. | You |
| 10 | **Deploy and schedule `lifecycle-emails`**, send a test digest with the new Resend key, enable Vercel Web Analytics | Confirms emails work end to end. | You + Claude |

## Not for this release

Stripe premium (test mode first), real Firebase project for push, Android/iOS
store releases (wait for about 100 active pairs).

## Recommendation to decide next week

If items 1 to 3 can be done in one sitting, the rest is mostly mechanical:
go for it. If the key leak (1) cannot be closed this week, do not merge.
