#!/bin/bash

echo "🔧 Fixing macOS build issues..."

# Set correct macOS deployment target
echo "➡️ Setting deployment target to 10.13..."

export MACOSX_DEPLOYMENT_TARGET=10.13
sed -i '' 's/MACOSX_DEPLOYMENT_TARGET = 10.11/MACOSX_DEPLOYMENT_TARGET = 10.13/g' macos/Podfile
sed -i '' 's/MACOSX_DEPLOYMENT_TARGET = 10.12/MACOSX_DEPLOYMENT_TARGET = 10.13/g' macos/Podfile

# Force deployment target override in Podfile
echo "
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.13'
    end
  end
end
" >> macos/Podfile

# Clean CocoaPods and reinstall
cd macos
rm -rf Pods Podfile.lock
pod install
cd ..

# Clean flutter and regenerate
flutter clean
flutter pub get

# Strip macOS code signing from debug builds
echo "🔒 Disabling code signing for debug macOS builds..."
sed -i '' 's/CODE_SIGN_IDENTITY = .*;/CODE_SIGN_IDENTITY = "";/g' macos/Runner.xcodeproj/project.pbxproj
sed -i '' 's/DEVELOPMENT_TEAM = .*;/DEVELOPMENT_TEAM = "";/g' macos/Runner.xcodeproj/project.pbxproj

# Done
echo "✅ MacOS build should now be fixed. Run: flutter run -d macos"

