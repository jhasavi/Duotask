# 🔧 Comprehensive Client ID Fix

## ✅ Correct Client IDs

### Web Client ID:
```
931322985925-rfik5s6jbo53h8rp35fc5itdo5jhm7b2.apps.googleusercontent.com
```

### iOS Client ID:
```
931322985925-oor0nc6g69l447l2ng9fpmkd4fbeksjh.apps.googleusercontent.com
```

## 🔧 Fixes Applied

### 1. Auth Service (lib/services/auth_service.dart):
```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'], // Use web client ID for all platforms
);
```

### 2. iOS Configuration (ios/Runner/Info.plist):
```xml
<key>GIDClientID</key>
<string>931322985925-oor0nc6g69l447l2ng9fpmkd4fbeksjh.apps.googleusercontent.com</string>

<key>CFBundleURLSchemes</key>
<array>
    <string>com.googleusercontent.apps.931322985925-oor0nc6g69l447l2ng9fpmkd4fbeksjh</string>
</array>
```

### 3. Android Configuration (android/app/src/main/AndroidManifest.xml):
```xml
<!-- Google Sign-In Configuration -->
<meta-data
    android:name="com.google.android.gms.version"
    android:value="@integer/google_play_services_version" />
```

## 🧪 Test All Platforms

### iOS Test:
```bash
flutter run -d "iPhone 16 Plus"
```

### Android Test:
```bash
flutter run -d android
```

### Web Test:
```bash
./run_web.sh
```

## ✅ Expected Results

### iOS:
- ✅ Native Google Sign-In UI
- ✅ Returns to app icon after sign-in
- ✅ No "Unacceptable audience" error

### Android:
- ✅ Native Google Sign-In UI
- ✅ Returns to app icon after sign-in
- ✅ No blank screen

### Web:
- ✅ Browser-based OAuth
- ✅ Redirects back to app

## 🚨 If Issues Persist

### For iOS "Unacceptable audience" error:
1. Go to Google Cloud Console
2. Find iOS client ID: `931322985925-oor0nc6g69l447l2ng9fpmkd4fbeksjh.apps.googleusercontent.com`
3. Ensure it's configured as **iOS** type (not Web)
4. Bundle ID: `com.example.duotask`

### For Android blank screen:
1. Check if Google Play Services is installed
2. Ensure Android emulator has Google Play Store
3. Check Android logs for specific errors

### For Web issues:
1. Ensure web client ID is in Google Cloud Console
2. Check Supabase redirect URLs
3. Clear browser cache 