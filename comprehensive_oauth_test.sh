#!/bin/bash

echo "🔍 COMPREHENSIVE OAUTH TEST SUITE"
echo "================================="
echo ""

# Test 1: Environment Variables
echo "📋 TEST 1: Environment Variables"
echo "--------------------------------"
if [ -f ".env" ]; then
    echo "✅ .env file exists"
    echo "Checking required variables:"
    
    # Check each required variable
    if grep -q "SUPABASE_URL" .env; then
        echo "✅ SUPABASE_URL found"
    else
        echo "❌ SUPABASE_URL missing"
    fi
    
    if grep -q "SUPABASE_ANON_KEY" .env; then
        echo "✅ SUPABASE_ANON_KEY found"
    else
        echo "❌ SUPABASE_ANON_KEY missing"
    fi
    
    if grep -q "GOOGLE_WEB_CLIENT_ID" .env; then
        echo "✅ GOOGLE_WEB_CLIENT_ID found"
    else
        echo "❌ GOOGLE_WEB_CLIENT_ID missing"
    fi
else
    echo "❌ .env file missing"
fi
echo ""

# Test 2: App Configuration
echo "📱 TEST 2: App Configuration"
echo "----------------------------"
echo "Checking auth_service.dart:"
if grep -q "http://localhost:5000" lib/services/auth_service.dart; then
    echo "✅ App configured to use localhost:5000"
else
    echo "❌ App not configured for localhost:5000"
fi
echo ""

# Test 3: Port Status
echo "🔌 TEST 3: Port Status"
echo "---------------------"
if lsof -i :5000 > /dev/null 2>&1; then
    echo "✅ Port 5000 is in use"
    echo "Processes on port 5000:"
    lsof -i :5000 | head -3
else
    echo "❌ Port 5000 is not in use"
fi
echo ""

# Test 4: Flutter Setup
echo "🛠️  TEST 4: Flutter Setup"
echo "------------------------"
echo "Flutter version:"
flutter --version | head -1
echo ""

# Test 5: Dependencies
echo "📦 TEST 5: Dependencies"
echo "----------------------"
if grep -q "supabase_flutter" pubspec.yaml; then
    echo "✅ supabase_flutter dependency found"
else
    echo "❌ supabase_flutter dependency missing"
fi

if grep -q "flutter_dotenv" pubspec.yaml; then
    echo "✅ flutter_dotenv dependency found"
else
    echo "❌ flutter_dotenv dependency missing"
fi
echo ""

# Test 6: Build Status
echo "🔨 TEST 6: Build Status"
echo "----------------------"
echo "Checking if app builds successfully..."
if flutter analyze > /dev/null 2>&1; then
    echo "✅ App builds without errors"
else
    echo "❌ App has build errors"
    echo "Running flutter analyze for details:"
    flutter analyze
fi
echo ""

# Test 7: Web Test
echo "🌐 TEST 7: Web OAuth Test"
echo "------------------------"
echo "Starting web test..."
echo "This will:"
echo "1. Launch the app on Chrome"
echo "2. Test Google Sign-In"
echo "3. Check for redirect_uri_mismatch"
echo ""
echo "Press Ctrl+C to stop the test"
echo ""

# Kill any existing Flutter processes
pkill -f "flutter run" 2>/dev/null
pkill -f "dart" 2>/dev/null

# Start web test
echo "🚀 Launching web app..."
timeout 60 flutter run -d chrome --web-port=5000 &
WEB_PID=$!

# Wait for app to start
sleep 30

# Check if app is running
if ps -p $WEB_PID > /dev/null; then
    echo "✅ Web app is running"
    echo "🌐 Open http://localhost:5000 in Chrome"
    echo "🔍 Test Google Sign-In and check for errors"
    echo ""
    echo "Press Enter when you've tested the OAuth flow..."
    read -r
    
    # Kill the web app
    kill $WEB_PID 2>/dev/null
else
    echo "❌ Web app failed to start"
fi
echo ""

# Test 8: iOS Test
echo "📱 TEST 8: iOS OAuth Test"
echo "------------------------"
echo "Checking iOS simulator..."
if flutter devices | grep -q "iPhone"; then
    echo "✅ iOS simulator available"
    echo "Starting iOS test..."
    echo "This will:"
    echo "1. Launch the app on iOS simulator"
    echo "2. Test Google Sign-In"
    echo "3. Check for redirect_uri_mismatch"
    echo ""
    echo "Press Ctrl+C to stop the test"
    echo ""
    
    timeout 60 flutter run -d "iPhone 16 Plus" &
    IOS_PID=$!
    
    sleep 30
    
    if ps -p $IOS_PID > /dev/null; then
        echo "✅ iOS app is running"
        echo "📱 Test Google Sign-In on iOS simulator"
        echo ""
        echo "Press Enter when you've tested the OAuth flow..."
        read -r
        
        kill $IOS_PID 2>/dev/null
    else
        echo "❌ iOS app failed to start"
    fi
else
    echo "❌ iOS simulator not available"
fi
echo ""

# Test 9: Android Test
echo "🤖 TEST 9: Android OAuth Test"
echo "-----------------------------"
echo "Checking Android emulator..."
if flutter devices | grep -q "android"; then
    echo "✅ Android device available"
    echo "Starting Android test..."
    echo "This will:"
    echo "1. Launch the app on Android"
    echo "2. Test Google Sign-In"
    echo "3. Check for redirect_uri_mismatch"
    echo ""
    echo "Press Ctrl+C to stop the test"
    echo ""
    
    timeout 60 flutter run -d android &
    ANDROID_PID=$!
    
    sleep 30
    
    if ps -p $ANDROID_PID > /dev/null; then
        echo "✅ Android app is running"
        echo "🤖 Test Google Sign-In on Android"
        echo ""
        echo "Press Enter when you've tested the OAuth flow..."
        read -r
        
        kill $ANDROID_PID 2>/dev/null
    else
        echo "❌ Android app failed to start"
    fi
else
    echo "❌ Android device not available"
    echo "Would you like to start an Android emulator? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Starting Android emulator..."
        ./test_android.sh
    fi
fi
echo ""

# Test 10: Configuration Summary
echo "📋 TEST 10: Configuration Summary"
echo "--------------------------------"
echo "CRITICAL CONFIGURATION CHECKLIST:"
echo ""
echo "🗄️  Supabase Dashboard:"
echo "   - Site URL: http://localhost:5000"
echo "   - Redirect URLs: http://localhost:5000"
echo "   - Google Provider Callback URL: http://localhost:5000"
echo ""
echo "🔐 Google Cloud Console:"
echo "   - Web Client Authorized redirect URIs: http://localhost:5000"
echo ""
echo "📱 App Configuration:"
echo "   - redirectUrl: http://localhost:5000"
echo ""
echo "❓ MANUAL VERIFICATION REQUIRED:"
echo "1. Go to Supabase Dashboard → Authentication → Providers → Google"
echo "2. Check if Callback URL is set to http://localhost:5000"
echo "3. If not, change it to http://localhost:5000"
echo "4. Go to Google Cloud Console → Credentials → Web Client"
echo "5. Check if http://localhost:5000 is in Authorized redirect URIs"
echo "6. If not, add http://localhost:5000"
echo ""
echo "🎯 EXPECTED BEHAVIOR:"
echo "- Web: Should redirect to http://localhost:5000"
echo "- Mobile: Should redirect to http://localhost:5000 (handled by Supabase)"
echo "- No redirect_uri_mismatch errors"
echo ""
echo "🚨 IF STILL FAILING:"
echo "1. Clear browser cache (Cmd+Shift+R)"
echo "2. Wait 5 minutes for Google Console changes to propagate"
echo "3. Check Supabase project is not paused"
echo "4. Verify all URLs match exactly (no trailing slashes)"
echo ""

echo "✅ Comprehensive OAuth test completed!"
echo "Check the results above and fix any issues found." 