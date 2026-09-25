// PLACEHOLDER — this is NOT a real Firebase configuration.
//
// This file exists so the app keeps compiling, analyzing, and testing
// without a real Firebase project. Push notifications will not actually be
// delivered until it's replaced with real values.
//
// To enable push notifications:
//   1. Create a Firebase project (console.firebase.google.com) and add it
//      as `firebase use` in this repo.
//   2. Run `flutterfire configure` from the repo root — it will overwrite
//      this exact file with real values and register the Android/iOS apps.
//   3. Commit the result normally (this file is intentionally NOT
//      gitignored — see .gitignore).
// Full steps: docs/PUSH_NOTIFICATIONS_SETUP.md
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Push notifications are not set up for web. See '
        'docs/PUSH_NOTIFICATIONS_SETUP.md.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Push notifications are not set up for this platform. See '
          'docs/PUSH_NOTIFICATIONS_SETUP.md.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'placeholder-not-a-real-key',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'duotask-placeholder',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'placeholder-not-a-real-key',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'duotask-placeholder',
    iosBundleId: 'com.example.duotask',
  );
}
