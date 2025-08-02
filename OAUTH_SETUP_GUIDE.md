# Google OAuth Setup Guide

## Current Issues
The Google sign-in is failing because of missing or incorrect configuration. Here's how to fix it:

## Step 1: Environment Configuration ✅

Your `.env` file is already configured with:
```bash
SUPABASE_URL=https://xqhlnuvpogiolzkucupt.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
GOOGLE_WEB_CLIENT_ID=931322985925-rfik5s6jbo53h8rp35fc5itdo5jhm7b2.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=931322985925-oor0nc6g69l447l2ng9fpmkd4fbeksjh.apps.googleusercontent.com
GOOGLE_OAUTH_REDIRECT_URL=http://localhost:5000
```

## Step 2: Configure Google OAuth in Supabase

1. In your Supabase Dashboard, go to Authentication → Providers
2. Enable Google provider
3. Add your Google OAuth credentials:
   - **Client ID**: `931322985925-rfik5s6jbo53h8rp35fc5itdo5jhm7b2.apps.googleusercontent.com`
   - **Client Secret**: Your Google OAuth client secret
4. Set the redirect URL to: `http://localhost:5000`

## Step 3: Configure Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to APIs & Services → Credentials
4. Edit your OAuth 2.0 Client ID (`931322985925-rfik5s6jbo53h8rp35fc5itdo5jhm7b2.apps.googleusercontent.com`)
5. Add these authorized redirect URIs:
   - `http://localhost:5000`
   - `https://xqhlnuvpogiolzkucupt.supabase.co/auth/v1/callback`

## Step 4: Test the Configuration

1. Run the app using the provided script:
   ```bash
   ./run_web.sh
   ```
2. Or manually: `flutter run -d chrome --web-port 5000`
3. Try signing in with Google
4. Check the browser console for any error messages

## Common Error Messages and Solutions

### "OAuth redirect URL mismatch"
- Make sure the redirect URL in Supabase matches your Google Cloud Console
- Ensure you're using port 5000 consistently
- Verify the redirect URL is exactly: `http://localhost:5000`

### "OAuth client configuration error"
- Verify your Google OAuth client ID and secret in Supabase
- Check that your Google Cloud Console project is properly configured
- Ensure the Google OAuth API is enabled

### "Missing Supabase configuration"
- Your `.env` file is already properly configured ✅
- The main.dart should automatically load these values

## Important Note About Ports

The app is now configured to use port 5000 consistently. Always run with:
```bash
flutter run -d chrome --web-port 5000
```

Or use the convenience script:
```bash
./run_web.sh
```

## Troubleshooting

1. **Check the console logs** for detailed error messages
2. **Verify all URLs match** between Supabase, Google Cloud Console, and your app
3. **Ensure you're using HTTPS** for production (localhost is fine for development)
4. **Check that Google OAuth API is enabled** in your Google Cloud Console
5. **Make sure you're running on port 5000** - not the random port Flutter assigns

## Next Steps

Once OAuth is working:
1. Test the complete sign-in flow
2. Verify user profile creation
3. Test the pairing functionality
4. Add error handling for edge cases 