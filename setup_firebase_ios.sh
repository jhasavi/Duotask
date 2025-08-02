#!/bin/bash

echo "🔥 Firebase iOS Setup Script (Push Notifications Only)"
echo "====================================================="

echo ""
echo "IMPORTANT: This app uses Supabase for authentication, not Firebase!"
echo "Firebase is only needed for future push notification features."
echo ""

# Check if FlutterFire CLI is installed
if ! command -v flutterfire &> /dev/null; then
    echo "❌ FlutterFire CLI not found. Installing..."
    dart pub global activate flutterfire_cli
    echo "✅ FlutterFire CLI installed"
else
    echo "✅ FlutterFire CLI already installed"
fi

echo ""
echo "Current Status:"
echo "✅ Authentication: Supabase (Google OAuth working)"
echo "⚠️  Push Notifications: Firebase (not configured yet)"
echo ""

echo "To enable push notifications in the future, you'll need to:"
echo ""
echo "1. Go to your Firebase Console: https://console.firebase.google.com/"
echo "2. Select your project: duotask-app"
echo "3. Add an iOS app if not already added:"
echo "   - Bundle ID: com.duotask.app"
echo "   - App nickname: DuoTask iOS"
echo ""
echo "4. Download the GoogleService-Info.plist file"
echo "5. Place it in: ios/Runner/GoogleService-Info.plist"
echo ""
echo "6. Run this command to configure Firebase:"
echo "   flutterfire configure"
echo ""

# Check if GoogleService-Info.plist exists
if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo "✅ GoogleService-Info.plist found (for future push notifications)"
else
    echo "ℹ️  GoogleService-Info.plist not needed yet (no push notifications)"
    echo ""
    echo "The app will work perfectly without Firebase for now!"
    echo "Authentication is handled by Supabase."
fi

echo ""
echo "Current app status:"
echo "✅ Web: Working with Supabase auth"
echo "✅ iOS: Should work now (Firebase removed from auth flow)"
echo "✅ Android: Should work with Supabase auth"
echo ""
echo "To test iOS now:"
echo "flutter run -d 'iPhone 16 Plus'" 