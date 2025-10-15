# Google OAuth Setup Guide - Hide Supabase URL

## Problem
When users sign in with Google, they see the Supabase URL in the consent screen, which exposes your backend infrastructure.

## Solution
Configure Google Cloud Console to show a custom app name instead of the Supabase URL.

## Step-by-Step Instructions

### 1. Access Google Cloud Console
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (or create one if you don't have one)

### 2. Navigate to OAuth Consent Screen
1. Go to **APIs & Services** > **OAuth consent screen**
2. If you haven't configured OAuth yet, click **Configure Consent Screen**

### 3. Configure App Information
1. **App name**: Enter "DuoTask" (or your preferred app name)
2. **User support email**: Enter your email
3. **App logo**: Upload your app logo (optional)
4. **App domain**: Add your domain (e.g., `localhost` for development)
5. **Developer contact information**: Enter your email

### 4. Configure Scopes
1. Click **Add or Remove Scopes**
2. Add these scopes:
   - `email`
   - `profile`
   - `openid`
3. Click **Update**

### 5. Configure Test Users (if in Testing)
1. If your app is in "Testing" mode, add test user emails
2. These users will be able to sign in during development

### 6. Publish App (Optional)
1. If you want to make it available to all users, click **Publish App**
2. Note: This requires Google's review process

### 7. Update OAuth Client ID
1. Go to **APIs & Services** > **Credentials**
2. Find your OAuth 2.0 Client ID
3. Click on it to edit
4. Update the **Authorized redirect URIs** to include:
   - `https://your-project.supabase.co/auth/v1/callback`
   - `http://localhost:3000/auth/callback` (for development)

### 8. Update Environment Variables
Make sure your `.env` file has the correct Google OAuth credentials:

```env
GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
GOOGLE_IOS_CLIENT_ID=your-ios-client-id.apps.googleusercontent.com
```

## Expected Result
After configuration:
- Users will see "DuoTask" instead of the Supabase URL
- The consent screen will look professional
- OAuth flow will work seamlessly

## Troubleshooting

### Still seeing Supabase URL?
1. Clear browser cache and cookies
2. Wait a few minutes for Google's changes to propagate
3. Make sure you're using the correct OAuth client ID

### OAuth not working?
1. Check that redirect URIs are correct
2. Verify environment variables are set
3. Ensure the app is published or test users are added

### Development vs Production
- For development: Use test users and localhost redirects
- For production: Publish the app and use your domain

## Security Notes
- Never commit your OAuth client secrets to version control
- Use environment variables for all sensitive data
- Regularly rotate your OAuth credentials
- Monitor OAuth usage in Google Cloud Console

## Additional Resources
- [Google OAuth Documentation](https://developers.google.com/identity/protocols/oauth2)
- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Flutter OAuth Guide](https://docs.flutter.dev/development/data-and-backend/state-mgmt/simple) 