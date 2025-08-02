# 🔧 Google Cloud Console Fix for Native Mobile OAuth

## 🚨 Current Issue
The error "Custom scheme URIs are not allowed for 'WEB' client type" indicates that the iOS client ID is configured as a **WEB** client instead of an **iOS** client in Google Cloud Console.

## 🔍 Problem Analysis

### Current Configuration:
- **iOS Client ID**: `931322985925-oor0nc6g69l447l2ng9fpmkd4fbeksjh.apps.googleusercontent.com`
- **Type**: Configured as WEB client (wrong)
- **Should be**: Configured as iOS client

### Correct Configuration:
- **Web Client ID**: `931322985925-rfik5s6jbo53h8rp35fc5itdo5jhm7b2.apps.googleusercontent.com` (for web)
- **iOS Client ID**: `931322985925-oor0nc6g69l447l2ng9fpmkd4fbeksjh.apps.googleusercontent.com` (for iOS native)

## 🔧 Fix Steps

### Step 1: Go to Google Cloud Console
1. Visit [https://console.cloud.google.com/](https://console.cloud.google.com/)
2. Select your DuoTask project
3. Navigate to **APIs & Services** → **Credentials**

### Step 2: Check Current Client IDs
You should have:
1. **Web client**: `931322985925-rfik5s6jbo53h8rp35fc5itdo5jhm7b2.apps.googleusercontent.com`
2. **iOS client**: `931322985925-oor0nc6g69l447l2ng9fpmkd4fbeksjh.apps.googleusercontent.com`

### Step 3: Fix iOS Client Configuration
1. Find the iOS client ID: `931322985925-oor0nc6g69l447l2ng9fpmkd4fbeksjh.apps.googleusercontent.com`
2. Click **Edit**
3. **Application type**: Should be **iOS** (not Web)
4. **Bundle ID**: Should be `com.example.duotask`
5. **Team ID**: Your Apple Developer Team ID
6. Click **Save**

### Step 4: Alternative - Create New iOS Client
If the current iOS client is corrupted:
1. Click **Create Credentials** → **OAuth 2.0 Client IDs**
2. **Application type**: iOS
3. **Bundle ID**: `com.example.duotask`
4. **Team ID**: Your Apple Developer Team ID
5. Copy the new client ID and update `Info.plist`

## 📱 App Configuration

### iOS Info.plist (Current):
```xml
<key>GIDClientID</key>
<string>931322985925-oor0nc6g69l447l2ng9fpmkd4fbeksjh.apps.googleusercontent.com</string>

<key>CFBundleURLSchemes</key>
<array>
    <string>com.googleusercontent.apps.931322985925-oor0nc6g69l447l2ng9fpmkd4fbeksjh</string>
</array>
```

### Auth Service (Current):
```dart
final GoogleSignIn _googleSignIn = GoogleSignIn();
```

## 🧪 Test After Fix

```bash
flutter clean && flutter pub get
cd ios && pod install && cd ..
flutter run -d "iPhone 16 Plus"
```

## ✅ Expected Result

- ✅ Native Google Sign-In UI appears
- ✅ No "Custom scheme URIs" error
- ✅ No "Unacceptable audience" error
- ✅ User gets signed in successfully
- ✅ Returns to app icon after sign-in

## 🚨 If Still Failing

1. **Check Bundle ID**: Ensure it matches in Google Console and Xcode
2. **Check Team ID**: Ensure it's correct in Google Console
3. **Create New iOS Client**: If current one is corrupted
4. **Wait 5 minutes**: Google Console changes can take time to propagate 