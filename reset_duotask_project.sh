#!/bin/bash

echo "🧹 Cleaning DuoTask project..."

# Step 1: Navigate to root project
cd "$(dirname "$0")"

# Step 2: Clean Dart and Flutter artifacts
flutter clean
rm -rf .dart_tool .packages pubspec.lock

# Step 3: Remove platform build folders
rm -rf build ios/Pods ios/Podfile.lock ios/.symlinks
rm -rf macos/Pods macos/Podfile.lock macos/.symlinks
rm -rf android/.gradle android/build

# Step 4: Reinstall all packages
flutter pub get

# Step 5: Recreate iOS/macOS configs
flutter create .
cd ios && pod install && cd ..
cd macos && pod install && cd ..

# Step 6: Remove problematic entitlements for macOS debug
echo "🧼 Resetting DebugProfile.entitlements..."
echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict></dict></plist>' > macos/Runner/DebugProfile.entitlements

# Step 7: Remove any old compiled native caches
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Step 8: Re-sign macOS .app ad hoc to bypass OSStatus 13
if [ -d "build/macos/Build/Products/Debug/duotask.app" ]; then
  echo "⚙️ Re-signing macOS .app..."
  codesign --remove-signature build/macos/Build/Products/Debug/duotask.app
  codesign --force --sign - --deep --timestamp=none build/macos/Build/Products/Debug/duotask.app
fi

echo "✅ Project reset complete."
echo "👉 Now run: flutter run -d macos OR flutter run -d ios"

