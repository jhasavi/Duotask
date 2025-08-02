#!/bin/bash

echo "🔍 DuoTask OAuth Debug Script"
echo "=============================="
echo ""

# Check Flutter setup
echo "📱 Flutter Setup:"
flutter --version
echo ""

# Check current platform
echo "🌐 Current Platform:"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS detected"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Linux detected"
else
    echo "Other OS: $OSTYPE"
fi
echo ""

# Check .env file
echo "📄 Environment Configuration:"
if [ -f ".env" ]; then
    echo "✅ .env file exists"
    echo "Contents:"
    cat .env | grep -E "(SUPABASE|GOOGLE)" | sed 's/=.*/=***HIDDEN***/'
else
    echo "❌ .env file missing"
    echo "Please create .env file with:"
    echo "SUPABASE_URL=your_supabase_url"
    echo "SUPABASE_ANON_KEY=your_supabase_anon_key"
    echo "GOOGLE_OAUTH_REDIRECT_URL=http://localhost:5000"
fi
echo ""

# Check port 5000
echo "🔌 Port 5000 Status:"
if lsof -i :5000 > /dev/null 2>&1; then
    echo "✅ Port 5000 is in use"
    lsof -i :5000 | head -5
else
    echo "❌ Port 5000 is not in use"
fi
echo ""

# Check Supabase configuration
echo "🗄️  Supabase Configuration Check:"
echo "1. Go to https://supabase.com/dashboard"
echo "2. Select your project"
echo "3. Go to Authentication > URL Configuration"
echo "4. Check these settings:"
echo "   - Site URL: http://localhost:5000"
echo "   - Redirect URLs: http://localhost:5000"
echo ""

# Check Google OAuth configuration
echo "🔐 Google OAuth Configuration Check:"
echo "1. Go to https://console.cloud.google.com/"
echo "2. Select your project"
echo "3. Go to APIs & Services > Credentials"
echo "4. Check your OAuth 2.0 Client IDs:"
echo "   - Web client: Should have http://localhost:5000 in authorized redirect URIs"
echo "   - iOS client: Should have your bundle ID"
echo "   - Android client: Should have your package name"
echo ""

# Check current auth service configuration
echo "⚙️  Current Auth Service Configuration:"
echo "Looking for redirect URL configuration..."
echo "Current redirect URL in auth_service.dart:"
grep -A 2 -B 2 "redirectUrl" lib/services/auth_service.dart || echo "No redirect URL found in auth service"
echo ""

# Check for OAuth provider configuration
echo "🔧 OAuth Provider Configuration:"
grep -n "OAuthProvider\|Provider" lib/services/auth_service.dart || echo "No OAuth provider configuration found"
echo ""

# Check for any Google Sign-In references
echo "🔍 Google Sign-In References:"
grep -r "google_sign_in\|GoogleSignIn" lib/ || echo "No Google Sign-In references found"
echo ""

# Check pubspec.yaml for OAuth dependencies
echo "📦 OAuth Dependencies:"
grep -A 5 -B 5 "supabase\|google" pubspec.yaml || echo "No OAuth dependencies found"
echo ""

echo "🎯 Next Steps:"
echo "1. For mobile OAuth, you need to use a different redirect URL"
echo "2. Consider using a custom URL scheme like 'duotask://auth/callback'"
echo "3. Or use a public URL that works on mobile devices"
echo "4. Check Supabase and Google Console configurations above"
echo ""

echo "📱 Mobile OAuth Solutions:"
echo "Option 1: Custom URL Scheme"
echo "  - Use 'duotask://auth/callback' for mobile"
echo "  - Configure in Supabase and Google Console"
echo ""
echo "Option 2: Public URL"
echo "  - Use a public URL like 'https://yourdomain.com/auth/callback'"
echo "  - Works on all platforms"
echo ""
echo "Option 3: Platform-specific URLs"
echo "  - Web: http://localhost:5000"
echo "  - Mobile: Custom scheme or public URL"
echo ""

echo "🔧 Quick Fix for Testing:"
echo "To test mobile OAuth immediately, try:"
echo "1. Use a public URL in your Supabase redirect URLs"
echo "2. Or implement a custom URL scheme"
echo "3. Or use a service like ngrok to expose localhost:5000 publicly"
echo "" 