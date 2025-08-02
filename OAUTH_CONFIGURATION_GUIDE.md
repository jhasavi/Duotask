# 🔐 OAuth Configuration Guide for DuoTask

## 📋 Overview
This guide will help you configure OAuth for both web and mobile platforms to fix the redirect issues.

## 🗄️ Supabase Configuration

### Step 1: Access Supabase Dashboard
1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Select your DuoTask project

### Step 2: Configure Authentication URLs
1. Navigate to **Authentication** → **URL Configuration**
2. Set the following values:

```
Site URL: http://localhost:5000

Redirect URLs (add both):
- http://localhost:5000
- https://www.namasteneedham.com/auth/callback.html
```

### Step 3: Configure Google OAuth Provider
1. Go to **Authentication** → **Providers**
2. Find **Google** and click **Edit**
3. Ensure these settings are configured:
   - **Enabled**: ✅ Yes
   - **Client ID**: Your Google Web Client ID
   - **Client Secret**: Your Google Web Client Secret
   - **Redirect URL**: `https://your-project-ref.supabase.co/auth/v1/callback`

## 🔐 Google Cloud Console Configuration

### Step 1: Access Google Cloud Console
1. Go to [https://console.cloud.google.com/](https://console.cloud.google.com/)
2. Select your DuoTask project

### Step 2: Configure OAuth Consent Screen
1. Navigate to **APIs & Services** → **OAuth consent screen**
2. Ensure your app is configured with:
   - **App name**: DuoTask-auth (or whatever you have configured)
   - **User support email**: Your email
   - **Developer contact information**: Your email

### Step 3: Configure OAuth 2.0 Client IDs

#### Web Client Configuration
1. Go to **APIs & Services** → **Credentials**
2. Find your **Web client** OAuth 2.0 Client ID
3. Click **Edit**
4. In **Authorized redirect URIs**, add:
   ```
   https://www.namasteneedham.com/auth/callback.html
   http://localhost:5000
   ```

#### iOS Client Configuration (if exists)
1. Find your **iOS client** OAuth 2.0 Client ID
2. Ensure **Bundle ID** matches: `com.example.duotask`
3. **Authorized redirect URIs** should include:
   ```
   https://xqhlnuvpogiolzkucupt.supabase.co/auth/v1/callback
   ```

#### Android Client Configuration (if exists)
1. Find your **Android client** OAuth 2.0 Client ID
2. Ensure **Package name** matches: `com.example.duotask`
3. **Authorized redirect URIs** should include:
   ```
   https://xqhlnuvpogiolzkucupt.supabase.co/auth/v1/callback
   ```

## 🔧 Environment Variables Check

Ensure your `.env` file contains:

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GOOGLE_WEB_CLIENT_ID=your-web-client-id
GOOGLE_IOS_CLIENT_ID=your-ios-client-id
GOOGLE_OAUTH_REDIRECT_URL=http://localhost:5000
```

## 📱 Testing the Configuration

### Web Testing
1. Run: `./run_web.sh`
2. Open Chrome and go to `http://localhost:5000`
3. Try Google Sign-In

### Mobile Testing
1. Run: `flutter run -d "iPhone 16 Plus"` or `flutter run -d android`
2. Try Google Sign-In
3. Should redirect to `duotask://auth/callback` instead of `http://localhost:5000`

## 🚨 Common Issues & Solutions

### Issue: "redirect_uri_mismatch"
**Solution**: Ensure all redirect URIs in Google Console match exactly what's configured in Supabase.

### Issue: "invalid_client"
**Solution**: Check that your Google Client ID and Secret are correctly configured in Supabase.

### Issue: Mobile still redirects to localhost
**Solution**: 
1. Clear app cache: `flutter clean && flutter pub get`
2. Rebuild: `flutter run -d "iPhone 16 Plus"`
3. Check that custom URL scheme is properly configured

### Issue: iOS build fails
**Solution**: 
1. Clean Xcode: `rm -rf ~/Library/Developer/Xcode/DerivedData`
2. Reinstall pods: `cd ios && pod install && cd ..`
3. Rebuild: `flutter run -d "iPhone 16 Plus"`

## 🔍 Debug Commands

Run the debug script to check your configuration:
```bash
./debug_oauth.sh
```

## 📞 Support

If you encounter issues:
1. Check the debug script output
2. Verify all URLs match exactly (including http/https)
3. Ensure no trailing slashes in URLs
4. Check that your Supabase project is active and not paused 