#!/bin/bash

echo "🔍 iOS Simulator Debug Script"
echo "=============================="

# Check if Flutter is properly installed
echo "1. Checking Flutter installation..."
flutter --version

echo ""
echo "2. Checking iOS development setup..."
flutter doctor -v

echo ""
echo "3. Checking available iOS simulators..."
xcrun simctl list devices | grep "iPhone"

echo ""
echo "4. Checking iOS build configuration..."
if [ -f "ios/Runner.xcodeproj/project.pbxproj" ]; then
    echo "✅ iOS project file exists"
else
    echo "❌ iOS project file missing"
fi

echo ""
echo "5. Checking iOS dependencies..."
if [ -f "ios/Podfile.lock" ]; then
    echo "✅ Podfile.lock exists"
    echo "Last updated: $(stat -f "%Sm" ios/Podfile.lock)"
else
    echo "❌ Podfile.lock missing - running pod install..."
    cd ios && pod install && cd ..
fi

echo ""
echo "6. Checking for common iOS issues..."

# Check Info.plist for required permissions
if grep -q "NSLocalNetworkUsageDescription" ios/Runner/Info.plist; then
    echo "✅ Local network permissions configured"
else
    echo "❌ Local network permissions missing"
fi

# Check for Firebase configuration
if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo "✅ Firebase configuration exists"
else
    echo "⚠️  Firebase configuration missing (may not be needed)"
fi

echo ""
echo "7. Cleaning and rebuilding..."
flutter clean
flutter pub get

echo ""
echo "8. Attempting to run on iOS simulator..."
echo "This will show detailed error messages if the app crashes..."

# Run with verbose output to catch errors
flutter run -d "iPhone 16 Plus" --verbose 