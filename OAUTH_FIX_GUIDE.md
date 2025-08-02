# 🔧 OAuth Fix Guide - redirect_uri_mismatch Error

## 🚨 Current Issue
You're getting `Error 400: redirect_uri_mismatch` because the redirect URL in your app doesn't match what's configured in Google Cloud Console.

## 🔧 Step-by-Step Fix

### Step 1: Check Current App Configuration
Your app is currently using: `https://xqhlnuvpogiolzkucupt.supabase.co/auth/v1/callback`

### Step 2: Update Google Cloud Console
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **APIs & Services** → **Credentials**
3. Find your **Web client** OAuth 2.0 Client ID
4. Click **Edit**
5. In **Authorized redirect URIs**, ensure you have:
   ```
   https://xqhlnuvpogiolzkucupt.supabase.co/auth/v1/callback
   http://localhost:5000
   ```
6. **Remove** any other redirect URIs that don't match
7. Click **Save**

### Step 3: Update Supabase Dashboard
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Authentication** → **URL Configuration**
4. Set:
   - **Site URL**: `http://localhost:5000`
   - **Redirect URLs**: `http://localhost:5000`
5. Go to **Authentication** → **Providers** → **Google**
6. Ensure **Callback URL** is: `https://xqhlnuvpogiolzkucupt.supabase.co/auth/v1/callback`

### Step 4: Test the Fix
```bash
# Test web
./run_web.sh

# Test mobile
flutter run -d "iPhone 16 Plus"
```

## 🎯 Alternative: Use Public Domain (After Basic Fix Works)

Once the basic OAuth is working, we can switch to your public domain:

### Step 5: Add Public Domain (Optional)
1. **Google Cloud Console**: Add `https://www.namasteneedham.com/auth/callback.html`
2. **Supabase**: Add `https://www.namasteneedham.com/auth/callback.html` to redirect URLs
3. **Update app**: Change redirect URL in `auth_service.dart`

## 🚨 Common Mistakes to Avoid

1. **Trailing slashes**: Don't add `/` at the end of URLs
2. **HTTP vs HTTPS**: Use exact protocol (http:// vs https://)
3. **Case sensitivity**: URLs are case-sensitive
4. **Extra spaces**: Remove any extra spaces in URLs

## 🔍 Debug Commands

```bash
# Check current configuration
./debug_oauth.sh

# Test OAuth flow
flutter run -d chrome
```

## 📞 If Still Not Working

1. **Clear browser cache**: Hard refresh (Cmd+Shift+R)
2. **Check console logs**: Look for OAuth errors
3. **Verify URLs**: Double-check all URLs match exactly
4. **Wait 5 minutes**: Google Console changes can take time to propagate 