# Send a task to someone without the app

*Built 2026-10-16. Not deployed: it ships with the next push of `main`, which
needs Phase 0 of [NEXT_STEPS.md](NEXT_STEPS.md) first.*

DuoTask only works once both people have signed up and paired, so every new
user has to talk someone into installing an app before they get any value.
Share links remove that step, and turn every task sent into an invitation to
the person most likely to sign up.

## How it works

1. **Sender**, in the app: open a task, tap **Send to someone**, optionally
   type the person's name, and pick WhatsApp, Text, Email or Copy link. The
   message goes from the sender's own phone:
   > Hi Sam! Could you take care of this? "Pick up the dry cleaning" (due Fri
   > Oct 17, 6:00 PM)
   > Tap to say you've got it or mark it done, no app needed:
   > https://duotask.namasteneedham.com/t/k3Jd9xQ2mPzR7vLwT0aYc8Ns
2. **Recipient**, no account: `/t/<token>` shows the task with **I'll do
   it**, **It's done** and **I can't do it**. Their answer updates the task
   (claimed, completed, back to unclaimed) and the sender sees it live, on the
   task's detail screen and in the send sheet.
3. **Conversion**: the page offers **Get DuoTask, free**, which opens
   `/?join=<token>`. The sign-up screen shows "Alex sent you …" and defaults to
   Sign Up. After sign-up, the task moves to the new account, and if neither
   person is paired yet, **they're paired automatically**: the task becomes a
   shared task on both boards.

## Why the sender sends it, not the server

There's no SMS provider. That means no Twilio bill, no US A2P 10DLC
registration, no opt-out handling, and no messages from an unknown short code
that carriers and people treat as spam. The message comes from someone the
recipient knows, in the app they already use, which is the best possible open
rate. A server-sent reminder ("Sam hasn't answered yet") can come later, as
email via Resend.

## Pieces

| Piece | Where |
|---|---|
| `task_shares` table and RPCs: `create_task_share`, `revoke_task_share`, `get_shared_task` (anon), `respond_to_shared_task` (anon), `claim_task_share` | `supabase/migrations/20261016000001_task_share_links.sql` |
| Recipient page: plain HTML/JS, about 10 KB, no Flutter download | `web/t/index.html` |
| Its config (Supabase URL and anon key), written at build time | `scripts/build_web.sh` → `build/web/t/config.js` |
| `/t/:token` routing, `no-referrer` and `noindex` headers | `vercel.json` |
| Model, service, send sheet | `lib/models/task_share.dart`, `lib/services/task_share_service.dart`, `lib/widgets/send_task_sheet.dart` |
| Hooks: detail-screen button, sign-up banner, claim on first load, `?join=` capture | `task_detail_screen.dart`, `auth_screen.dart`, `home_screen.dart`, `main.dart` |
| Share link base for native builds | `PUBLIC_APP_URL` (defaults to the production domain; the web app uses its own origin) |

## Security and privacy

- **The token is the credential**: 18 random bytes (144 bits), URL-safe. It
  can't be guessed. Links expire after 30 days, and the sender can turn one off
  at any time (the old URL then says "This link was turned off").
- **Anon can only use the two token RPCs.** `anon` has no privileges on
  `task_shares`, and RLS hides `tasks` from it, as before. The page sees the
  title, notes, due date, priority and status, plus the sender's display name,
  and only when the display name isn't an email address. It never sees email
  addresses or user IDs.
- **Opening the page changes nothing.** Only button presses do. Link-preview
  bots (WhatsApp, iMessage, Slack) fetch the URL but don't run JavaScript, so
  they can't accept or complete a task.
- **The token stays out of other sites' logs**: `Referrer-Policy: no-referrer`
  plus `noindex`.
- **Scope**: only the creator's own **personal, one-time, unfinished** tasks.
  - Group tasks have an ownership lock (only the claimer completes) that a
    guest can't satisfy.
  - Recurring tasks get their next occurrence from the app, which a guest
    isn't running.
  - The app hides the button in those cases, and the RPC refuses them.
- **Privacy policy §3.2** describes all of this.

## What's measured

New `analytics.events`:
- `share_created`: when the sheet first opens for a task, since the link is
  made then
- `share_opened`: first open only
- `share_accepted`, `share_declined`, `share_done`
- `share_claimed`, with `props.paired`

The funnel to watch:

```sql
select count(*) filter (where event = 'share_created')  as links,
       count(*) filter (where event = 'share_opened')   as opened,
       count(*) filter (where event in ('share_accepted','share_done')) as responded,
       count(*) filter (where event = 'share_claimed')  as signed_up,
       count(*) filter (where event = 'share_claimed' and (props->>'paired')::boolean) as paired
from analytics.events
where created_at > now() - interval '30 days';
```

Targets to beat, as a first guess: 60%+ opened, 40%+ of opens respond, 10%+
of responders sign up. If opens are low, the message copy is the problem. If
sign-ups are low, the "Keep track together" card is.

## How it was tested

- **Unit and widget tests** (`flutter test --exclude-tags integration`):
  - Model and message building
  - Service, including the join flow: claim, clear, and keeping the token
    after a network failure
  - Send sheet: link made on open, channel URIs, copy, the fallback when the
    clipboard is blocked, errors
- **Integration tests** (`test/integration/task_share_test.dart`), run on
  2026-10-16 against a local `supabase start` stack with the full migration
  chain. They cover:
  - Owner-only sharing and link reuse
  - Anon visibility, and no email leak
  - Accept, done, undo and decline
  - Revoked and expired links
  - Claim with auto-pair, followed by the new user completing the task
  - Claim when the sender is already paired
  - Rejection of "own link" and "already claimed"

  See [TESTING_GUIDE.md](../TESTING_GUIDE.md#running-integration-tests-locally)
  to run them yourself.
- **End to end in a browser** (a local build against the same stack):
  - Opening the link, accepting
  - "Get DuoTask", then the sign-up banner
  - Sign-up, then auto-pair, with the task shown in progress on the new board
  - The sender's sheet updating live to "Mom marked it done"
  - Turning off the link

## Known limits and next steps

- **No reminder if the recipient never opens the link.** A good follow-up is
  a push to the sender after 24 hours ("Sam hasn't opened it, send again?").
- **Repeating and shared tasks can't be sent by link.** Supporting them needs
  the guest to count as the claimer for the ownership lock, and the next
  occurrence created on the server.
- **The link preview is generic** ("A task for you on DuoTask"): the page is
  static, so WhatsApp can't show the task title. Showing it would need a
  server-rendered `/t/:token` (for example a Vercel function), which would
  then expose the title to the preview bot.
- **One live link per task.** Sending the same task to two people sends the
  same link, and the first to act wins.
