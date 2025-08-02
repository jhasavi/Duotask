# ✅ OAuth Configuration Checklist

## 🗄️ Supabase Dashboard (Required)

- [ ] **Site URL**: `http://localhost:5000`
- [ ] **Redirect URLs**: 
  - [ ] `http://localhost:5000` (for web)
  - [ ] `https://www.namasteneedham.com/auth/callback.html` (for mobile)
- [ ] **Google Provider**: Enabled with correct Client ID/Secret

## 🔐 Google Cloud Console (Required)

- [ ] **OAuth Consent Screen**: App name is "DuoTask-auth" (or your configured name)
- [ ] **Web Client** → **Authorized redirect URIs**:
  - [ ] `https://www.namasteneedham.com/auth/callback.html`
  - [ ] `http://localhost:5000`

## 📱 App Configuration (Already Done ✅)

- [ ] ✅ Platform-specific redirect URLs implemented
- [ ] ✅ Custom URL scheme `duotask://` added to iOS
- [ ] ✅ Custom URL scheme `duotask://` added to Android
- [ ] ✅ Xcode cache cleaned
- [ ] ✅ Pods reinstalled

## 🧪 Testing Steps

1. **Web Test**:
   ```bash
   ./run_web.sh
   ```
   - Open Chrome → `http://localhost:5000`
   - Try Google Sign-In

2. **Mobile Test**:
   ```bash
   flutter run -d "iPhone 16 Plus"
   ```
   - Try Google Sign-In
   - Should redirect to `duotask://auth/callback`

## 🚨 If Still Not Working

1. **Check Supabase Project Status**: Ensure project is not paused
2. **Verify URLs**: No trailing slashes, exact matches
3. **Clear Browser Cache**: Hard refresh (Cmd+Shift+R)
4. **Check Console Logs**: Look for OAuth errors

## 📞 Quick Debug

Run this to check your setup:
```bash
./debug_oauth.sh
``` 