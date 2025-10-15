#!/bin/bash

echo "✅ Updating macOS deployment target to 10.13..."

# Update macOS deployment target in Xcode project
sed -i '' 's/MACOSX_DEPLOYMENT_TARGET = 10.12/MACOSX_DEPLOYMENT_TARGET = 10.13/g' macos/Runner.xcodeproj/project.pbxproj
sed -i '' 's/MACOSX_DEPLOYMENT_TARGET = 10.11/MACOSX_DEPLOYMENT_TARGET = 10.13/g' macos/Runner.xcodeproj/project.pbxproj

# Update Pods deployment target
echo "macos.deployment_target = '10.13'" > macos/Podfile.local

# Reset pods and rebuild
echo "🔄 Running pod install..."
cd macos
rm -rf Pods Podfile.lock
pod install
cd ..

# Flutter cleanup
echo "🧹 Cleaning Flutter build cache..."
flutter clean
flutter pub get

# Disable code signing requirement for debug build (macOS only)
echo "🛠 Disabling code signing in debug build for macOS..."
plutil -replace CODE_SIGN_IDENTITY -string "" macos/Runner.xcodeproj/project.pbxproj

# Done
echo "✅ Done! Try: flutter run -d macos"

