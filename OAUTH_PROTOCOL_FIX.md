# 🔧 OAuth Protocol Fix Guide

## 🚨 The Issue
You're getting `redirect_uri_mismatch` because of protocol mismatches (http vs https).

## 🔍 Current Configuration Analysis

### App Configuration:
- **App is using**: `https://xqhlnuvpogiolzkucupt.supabase.co/auth/v1/callback`
- **Web app runs on**: `http://localhost:5000`

### Google Cloud Console (likely has):
- `http://localhost:5000` (for web)
- Missing: `https://xqhlnuvpogiolzkucupt.supabase.co/auth/v1/callback`

## 🔧 Fix Options

### Option 1: Use localhost for Web (Recommended for Testing)
```dart
// In auth_service.dart
const redirectUrl = 'http://localhost:5000';
```

### Option 2: Use Supabase Callback (Recommended for Production)
```dart
// In auth_service.dart
const redirectUrl = 'https://xqhlnuvpogiolzkucupt.supabase.co/auth/v1/callback';
```

## 📝 Required Google Cloud Console Configuration

### For Option 1 (localhost):
```
Authorized redirect URIs:
- http://localhost:5000
```

### For Option 2 (Supabase callback):
```
Authorized redirect URIs:
- https://xqhlnuvpogiolzkucupt.supabase.co/auth/v1/callback
- http://localhost:5000
```

## 🎯 Quick Fix Steps

1. **Choose your approach** (localhost or Supabase callback)
2. **Update Google Cloud Console** with the correct redirect URIs
3. **Update the app** to use the matching redirect URL
4. **Test on all platforms**

## 🧪 Testing Commands

```bash
# Test web
./run_web.sh

# Test iOS
flutter run -d "iPhone 16 Plus"

# Test Android
chmod +x test_android.sh && ./test_android.sh
```

## ⚠️ Important Notes

- **Protocol matters**: `http://` ≠ `https://`
- **No trailing slashes**: `localhost:5000` ≠ `localhost:5000/`
- **Case sensitive**: URLs are case-sensitive
- **Wait 5 minutes**: Google Console changes can take time to propagate 