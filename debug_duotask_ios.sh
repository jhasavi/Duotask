#!/bin/bash

echo "🔍 Starting full iOS Flutter+Firebase project debug..."
echo "==============================================="
echo

# 1. Flutter doctor
echo "📦 Checking Flutter SDK & env:"
flutter doctor -v
echo
echo "==============================================="

# 2. Check Firebase options
echo "🔐 Verifying firebase_options.dart..."
if [ -f "lib/firebase_options.dart" ]; then
  grep -E "projectId|apiKey|appId|messagingSenderId" lib/firebase_options.dart
else
  echo "⚠️ firebase_options.dart not found!"
fi
echo "==============================================="

# 3. GoogleService-Info.plist check
echo "📁 Checking GoogleService-Info.plist placement..."
if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
  echo "✅ GoogleService-Info.plist found."
else
  echo "❌ GoogleService-Info.plist NOT found in ios/Runner!"
fi
echo "==============================================="

# 4. Pod install check
echo "📦 Checking CocoaPods setup:"
cd ios
pod install --repo-update
cd ..
echo "==============================================="

# 5. Info.plist reversed client ID
echo "🔍 Checking Info.plist for REVERSED_CLIENT_ID..."
grep -A3 "CFBundleURLSchemes" ios/Runner/Info.plist
echo "==============================================="

# 6. Check for required plugins in pubspec.yaml
echo "📦 Checking pubspec.yaml for essential Firebase plugins..."
grep -E "firebase_auth|firebase_core|google_sign_in|firebase_messaging|flutter_local_notifications" pubspec.yaml
echo "==============================================="

# 7. Dart analysis
echo "🧪 Running 'flutter analyze' to catch syntax/type errors..."
flutter analyze
echo "==============================================="

# 8. Check platform version in Podfile
echo "📱 Verifying iOS deployment target in ios/Podfile..."
grep "platform :ios" ios/Podfile
echo "==============================================="

# 9. Validate GoogleSignIn is imported
echo "🔍 Searching for GoogleSignIn import in auth_service.dart..."
grep "import 'package:google_sign_in/google_sign_in.dart'" lib/services/auth_service.dart || echo "❌ Missing import!"
echo "==============================================="

# 10. Try building for iOS
echo "🚀 Attempting iOS build (simulator)..."
flutter build ios --debug
echo "==============================================="

echo "✅ Debugging script finished. Scroll up for any ❌ or ⚠️."

