# Push notifications setup

Nudges currently reach a recipient only while they have the app open (via a
Supabase Realtime subscription — see `NudgeService._setupRealtimeSubscription`
in `lib/services/nudge_service.dart`). The code in this repo adds real push
delivery on top of that, so a nudge reaches someone even if the app is
backgrounded or closed. Everything code-side is done; this document is the
**one-time manual setup** needed to turn it on — it can't be automated from
inside the repo.

## What's already built

- `device_tokens` table + `send-nudge-push` edge function
  (`supabase/migrations/20260917000001_device_tokens_and_nudge_push.sql`,
  `supabase/functions/send-nudge-push/`) — a trigger fires this function on
  every `nudges` insert, which looks up the recipient's registered devices
  and sends each one a push via FCM's v1 API.
- Client-side FCM wiring in `lib/services/notification_service.dart` —
  requests permission, registers the device's token, keeps it fresh, and
  renders a local notification when a push arrives in the foreground (FCM
  doesn't display foreground pushes itself; Android/iOS handle background/
  terminated display automatically from the payload).
- `lib/firebase_options.dart` is a **placeholder** so the app keeps
  compiling and passing CI without a real Firebase project — none of this
  is active until you complete the steps below.

## 1. Create a Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com) →
   **Add project**. Reuse an existing Google Cloud project if you have one,
   or create a new one.
2. You do **not** need Analytics for this — Cloud Messaging only.

## 2. Register the Android and iOS apps and generate real config

From the repo root:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Follow the prompts (pick the Firebase project from step 1, select Android +
iOS). This overwrites `lib/firebase_options.dart` with real values and drops
`android/app/google-services.json` / `ios/Runner/GoogleService-Info.plist`
into place. Commit `lib/firebase_options.dart` normally — it's not a secret
(same status as the Supabase anon key: a client identifier, not something
that grants access by itself). The two platform config files stay
gitignored.

Android's `applicationId` is currently the Flutter default,
`com.example.duotask` (`android/app/build.gradle.kts`) — decide on a real
one and update it *before* running `flutterfire configure`, since the
Android app is registered in Firebase against whatever `applicationId` is
set at the time.

## 3. iOS: upload an APNs key

Firebase needs an APNs authentication key to deliver to iOS devices:

1. [Apple Developer](https://developer.apple.com/account) → **Certificates,
   Identifiers & Profiles** → **Keys** → create a new key with the **Apple
   Push Notifications service (APNs)** capability. Download the `.p8` file
   (you can only download it once).
2. Firebase console → Project Settings → **Cloud Messaging** tab → **Apple
   app configuration** → upload that `.p8` file, along with the Key ID and
   your Apple Team ID.

## 4. Create a service account key for the edge function

The edge function authenticates to FCM's v1 API as a service account, not
with a legacy server key (that API is retired):

1. Firebase console → Project Settings → **Service accounts** → **Generate
   new private key**. This downloads a JSON file.
2. Set it as a Supabase function secret (this is a secret — never commit it):

   ```bash
   supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat path/to/serviceAccountKey.json)"
   ```

## 5. Deploy the edge function and run the migration

```bash
supabase db push          # applies 20260917000001_device_tokens_and_nudge_push.sql
supabase functions deploy send-nudge-push
```

The migration's trigger reuses the `project_url` / `anon_key` Vault secrets
already set up for the daily email digest
(`supabase/migrations/20250625000005_setup_email_cron.sql`) — if those
aren't set yet, nudges will still insert fine, they just won't trigger a
push until the secrets exist (see that migration's header for how to set
them).

## Verifying it works

1. Build and install on a real device (the iOS Simulator and Android
   emulator don't support push): `flutter run --release`.
2. Sign in — this registers the device's FCM token in `device_tokens`
   (check the table in the Supabase dashboard).
3. From a second account paired with the first, send a nudge. The first
   device should get a push within a few seconds, even backgrounded.
4. Check `supabase functions logs send-nudge-push` if nothing arrives —
   it reports `sent`, `failed`, and `removed_stale` counts per call.

## Known limitations of this first pass

- **Web is not covered.** `NotificationService.registerForPushNotifications`
  and `main.dart`'s Firebase init both skip `kIsWeb`. Web push needs a VAPID
  key and a service worker, which is more setup than mobile — left for a
  follow-up.
- **A device token isn't removed on sign-out.** If two different people use
  the same physical device, the previous user's token stays registered
  until FCM reports it as stale (which only happens once a push actually
  fails to deliver to it, e.g. after a fresh install for a different
  account overwrites the OS-level token). Low-impact for how this app is
  used today (paired, personal devices), but worth fixing before a public
  launch with less predictable usage.
- **No notification tap deep-linking yet.** A tapped push currently opens
  the app to its default screen rather than the relevant nudge/task.
