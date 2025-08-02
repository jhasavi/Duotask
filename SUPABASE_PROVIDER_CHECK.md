# 🔍 Supabase Google Provider Configuration Check

## 🚨 The Issue
Even though the app code shows `http://localhost:5000`, the OAuth is still using `https://xqhlnuvpogiolzkucupt.supabase.co/auth/v1/callback`.

## 🔍 Root Cause
This happens when Supabase's Google provider has its own callback URL configured that overrides the app's redirect URL.

## 🔧 Fix Steps

### Step 1: Check Supabase Google Provider
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Authentication** → **Providers**
4. Find **Google** and click **Edit**
5. **Check the Callback URL field**

### Step 2: Update Supabase Google Provider
**If the Callback URL is set to:**
```
https://xqhlnuvpogiolzkucupt.supabase.co/auth/v1/callback
```

**Change it to:**
```
http://localhost:5000
```

### Step 3: Alternative - Remove Callback URL
**Or completely remove the Callback URL** from the Google provider configuration and let the app handle it.

## 🎯 Why This Happens

1. **Supabase Provider Configuration** takes precedence over app code
2. **If Callback URL is set** in the provider, it overrides `redirectTo` parameter
3. **The app code** is ignored when provider has its own callback URL

## 🧪 Test After Fix

```bash
# Clean restart
flutter clean && flutter pub get

# Test web
./run_web.sh

# Test mobile
flutter run -d "iPhone 16 Plus"
```

## 📝 Expected Result

After fixing the Supabase provider configuration:
- **App should use**: `http://localhost:5000`
- **Google Console should have**: `http://localhost:5000`
- **No more**: `redirect_uri_mismatch` errors 