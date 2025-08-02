# DuoTask OAuth Branding Configuration

## 🎯 **Goal: Hide Supabase URL in OAuth Flow**

To make the OAuth flow show "DuoTask" instead of the Supabase URL, you need to configure the OAuth settings in your Supabase project.

## 🔧 **Step 1: Configure Supabase OAuth Settings**

### **1.1 Update OAuth Redirect URLs**
In your Supabase Dashboard:

1. Go to **Authentication** → **URL Configuration**
2. Add these redirect URLs:
   ```
   http://localhost:5000
   http://localhost:3000
   https://yourdomain.com/auth/callback
   ```

### **1.2 Configure Site URL**
1. Go to **Authentication** → **URL Configuration**
2. Set **Site URL** to: `https://duotask.app` (or your domain)
3. Set **Redirect URLs** to include your production URLs

### **1.3 Customize OAuth Provider**
1. Go to **Authentication** → **Providers** → **Google**
2. Configure:
   - **Client ID**: Your Google OAuth client ID
   - **Client Secret**: Your Google OAuth client secret
   - **Redirect URL**: `https://yourdomain.com/auth/callback`

## 🌐 **Step 2: Production Domain Setup**

### **2.1 Custom Domain**
For production, set up a custom domain like:
- `https://duotask.app`
- `https://app.duotask.com`
- `https://duotask.yourdomain.com`

### **2.2 OAuth Redirect URLs**
Add these to your Supabase OAuth settings:
```
https://duotask.app/auth/callback
https://app.duotask.com/auth/callback
```

## 📱 **Step 3: Update App Configuration**

### **3.1 Environment Variables**
Update your `.env` file:
```bash
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
GOOGLE_OAUTH_REDIRECT_URL=https://duotask.app/auth/callback
```

### **3.2 Google OAuth Console**
1. Go to Google Cloud Console
2. Add authorized redirect URIs:
   ```
   https://duotask.app/auth/callback
   https://your-project.supabase.co/auth/v1/callback
   ```

## 🎨 **Step 4: Custom Branding (Optional)**

### **4.1 App Logo**
Add your app logo to the OAuth flow:
1. Upload logo to your domain
2. Update OAuth settings with logo URL
3. Configure app name in OAuth provider

### **4.2 Custom OAuth Page**
For complete control, you can create a custom OAuth page:
1. Host a custom OAuth page at `https://duotask.app/auth`
2. Handle OAuth flow with your own branding
3. Redirect to Supabase for authentication

## 🔒 **Security Considerations**

### **5.1 HTTPS Required**
- All production URLs must use HTTPS
- Localhost URLs are only for development

### **5.2 Domain Verification**
- Verify your domain with Google OAuth
- Add domain to authorized domains in Supabase

## 📋 **Current Status**

### **Development (Current)**
- ✅ Uses localhost URLs
- ✅ OAuth flow works
- ⚠️ Shows Supabase URL (expected in development)

### **Production (Target)**
- 🔄 Custom domain needed
- 🔄 OAuth branding configuration
- 🔄 HTTPS setup required

## 🚀 **Next Steps**

1. **Set up custom domain** (duotask.app or similar)
2. **Configure Supabase OAuth settings** with production URLs
3. **Update Google OAuth console** with new redirect URIs
4. **Deploy app** to production domain
5. **Test OAuth flow** with custom branding

## 💡 **Alternative Solutions**

### **Option 1: Custom OAuth Page**
Create a custom OAuth page that handles the flow:
```dart
// Custom OAuth flow
final response = await _client.auth.signInWithOAuth(
  Provider.google,
  redirectTo: 'https://duotask.app/auth/callback',
);
```

### **Option 2: OAuth Proxy**
Use a proxy service to handle OAuth with custom branding:
- Auth0
- Firebase Auth
- Custom OAuth proxy

### **Option 3: Native OAuth**
Use native Google Sign-In SDKs:
- iOS: Google Sign-In SDK
- Android: Google Sign-In SDK
- Web: Google Identity Services

## 📞 **Support**

For help with OAuth configuration:
1. Check Supabase documentation
2. Review Google OAuth setup guide
3. Test with development URLs first
4. Gradually migrate to production URLs

---

**Note**: The current development setup shows Supabase URLs, which is normal. For production, follow the steps above to create a branded OAuth experience. 