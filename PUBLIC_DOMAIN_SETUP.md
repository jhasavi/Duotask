# 🌐 Public Domain OAuth Setup Guide

## 📋 Overview
Using your public domain `namasteneedham.com` for OAuth redirects is the most reliable solution for mobile authentication.

## 🔧 Setup Steps

### Step 1: Create Auth Redirect Page
Create a simple HTML page at `https://namasteneedham.com/auth/callback.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>DuoTask - Authentication</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
            background: rgba(255,255,255,0.1);
            border-radius: 16px;
            backdrop-filter: blur(10px);
        }
        .spinner {
            border: 3px solid rgba(255,255,255,0.3);
            border-top: 3px solid white;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 1rem;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="spinner"></div>
        <h2>Completing Sign In...</h2>
        <p>Please wait while we complete your authentication.</p>
    </div>
    
    <script>
        // Handle OAuth callback
        const urlParams = new URLSearchParams(window.location.search);
        const code = urlParams.get('code');
        const error = urlParams.get('error');
        
        if (error) {
            document.querySelector('.container').innerHTML = `
                <h2>Authentication Error</h2>
                <p>Error: ${error}</p>
                <button onclick="window.close()">Close</button>
            `;
        } else if (code) {
            // Success - close window or redirect
            setTimeout(() => {
                window.close();
            }, 2000);
        }
    </script>
</body>
</html>
```

### Step 2: Update Auth Service
Update `lib/services/auth_service.dart`:

```dart
// Use your public domain for all platforms
const redirectUrl = 'https://namasteneedham.com/auth/callback.html';
```

### Step 3: Update Google Cloud Console
In **Authorized redirect URIs**, add:
```
https://namasteneedham.com/auth/callback.html
```

### Step 4: Update Supabase Dashboard
In **Redirect URLs**, add:
```
https://namasteneedham.com/auth/callback.html
```

## ✅ Benefits of Public Domain Approach

1. **Works on all platforms** - web, iOS, Android
2. **No custom URL schemes** - Google accepts it
3. **Professional appearance** - branded redirect page
4. **Reliable** - no localhost issues
5. **Future-proof** - works in production

## 🚀 Quick Implementation

Would you like me to:
1. Create the HTML file for you to upload
2. Update the auth service code
3. Update the configuration guides

This approach will solve all the mobile OAuth issues permanently! 