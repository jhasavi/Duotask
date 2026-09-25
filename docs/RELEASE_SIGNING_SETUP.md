# Android release signing setup

Release builds currently sign with the **debug** keystore — fine for local
testing (`flutter run --release`, `flutter build apk --debug`), but Google
Play will reject an upload signed that way, and it's a bad practice to ship
with debug keys regardless. The Gradle config in
`android/app/build.gradle.kts` is already wired to use a real release
keystore the moment one exists; this document is the one-time step to
create it.

**Do this yourself, in your own terminal** — not through this session. The
keystore and its passwords are a long-lived credential: losing the keystore
means you can never publish an update to this app again under its current
Play Store listing (short of Google's account-recovery process, which is
slow and not guaranteed), and typing the password into a chat session is
unnecessary exposure for something this sensitive.

## 1. Generate the keystore

From the repo root:

```bash
keytool -genkey -v \
  -keystore android/release-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

`keytool` ships with any JDK (Android Studio bundles one; `which keytool`
should find it). It will prompt for:

- A **keystore password** and a **key password** (can be the same value) —
  pick something you'll store in a password manager. This is the part that
  must never be lost or leaked.
- Your name, organization, city, state, country — these go into the
  certificate and are not sensitive; anything reasonable works.

This creates `android/release-keystore.jks`. **Back it up somewhere
durable and private** (a password manager's file storage, an encrypted
drive) — not just on this one machine.

## 2. Point the build at it

```bash
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties` and fill in the password(s) and alias you
just chose. It's already gitignored — verify with `git status` that it
doesn't show up before committing anything else.

## 3. Verify

```bash
flutter build apk --release
```

Gradle's warning about signing with the debug key (printed during
`flutter build`/`flutter run` when `android/key.properties` is missing)
should be gone. To double check the APK is actually signed with your key
rather than the debug one:

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

The certificate fingerprint should match `keytool -list -v -keystore
android/release-keystore.jks -alias upload` (same SHA-256 fingerprint), not
the debug keystore's.

## Play App Signing (recommended, optional)

Google Play offers **Play App Signing**, where Google holds the final
signing key and you upload with this "upload key" instead — if the upload
key is ever lost or compromised, Google can help you rotate it without
losing the app's identity, which a pure self-managed keystore can't offer.
It's opt-in on your first release to Play Console, using the exact keystore
generated above as the upload key. Worth doing when you get to the actual
Play Console submission; no extra local setup beyond what's already here.
