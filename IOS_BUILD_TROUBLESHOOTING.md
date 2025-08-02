# iOS Build Troubleshooting Guide

## 🔧 **Common iOS Build Issues and Solutions**

### **Issue: Xcode Derived Data Errors**
```
Error (Xcode): unable to open dependencies file
Error (Xcode): Failed to query serialized dependencies
```

#### **Solution:**
```bash
# 1. Clean Flutter project
flutter clean

# 2. Remove Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# 3. Get dependencies
flutter pub get

# 4. Reinstall iOS pods
cd ios && pod install && cd ..

# 5. Run the app
flutter run -d ios
```

---

### **Issue: Pod Installation Errors**
```
[!] Invalid `Podfile` file: Flutter/Generated.xcconfig must exist
```

#### **Solution:**
```bash
# 1. Run flutter pub get first
flutter pub get

# 2. Then install pods
cd ios && pod install && cd ..
```

---

### **Issue: CocoaPods Configuration Warnings**
```
[!] CocoaPods did not set the base configuration of your project
```

#### **Solution:**
This is a warning, not an error. The app should still build successfully. If you want to fix it:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner project
3. Go to Build Settings
4. Set the base configuration for each target

---

### **Issue: Firebase Configuration Errors**
```
Error: Could not find 'GoogleService-Info.plist'
```

#### **Solution:**
1. Download `GoogleService-Info.plist` from Firebase Console
2. Add it to `ios/Runner/` directory
3. Make sure it's included in the Runner target

---

### **Issue: OAuth URL Scheme Errors**
```
Error: URL scheme not found
```

#### **Solution:**
1. Check `ios/Runner/Info.plist` has the correct URL scheme:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

---

### **Issue: iOS Deployment Target Errors**
```
Error: iOS deployment target '12.0' is not supported
```

#### **Solution:**
1. Update `ios/Podfile`:
```ruby
platform :ios, '13.0'
```

2. Update `ios/Runner.xcodeproj/project.pbxproj`:
```
IPHONEOS_DEPLOYMENT_TARGET = 13.0;
```

---

### **Issue: Build Archive Errors**
```
Error: Multiple commands produce
```

#### **Solution:**
```bash
# 1. Clean everything
flutter clean
rm -rf ios/build
rm -rf ios/Pods

# 2. Reinstall
flutter pub get
cd ios && pod install && cd ..

# 3. Build again
flutter build ios
```

---

## 🚀 **Complete iOS Build Process**

### **Step-by-Step Build Process:**
```bash
# 1. Clean project
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Install iOS pods
cd ios && pod install && cd ..

# 4. Run on iOS simulator
flutter run -d ios

# 5. Or build for release
flutter build ios
```

---

## 📱 **iOS Simulator Commands**

### **List Available Simulators:**
```bash
flutter devices
```

### **Run on Specific Simulator:**
```bash
flutter run -d "iPhone 16 Plus"
```

### **Open Simulator:**
```bash
open -a Simulator
```

---

## 🔍 **Debugging Commands**

### **Check Flutter Doctor:**
```bash
flutter doctor -v
```

### **Check iOS Setup:**
```bash
flutter doctor --android-licenses
```

### **Analyze Code:**
```bash
flutter analyze
```

### **Check Dependencies:**
```bash
flutter pub deps
```

---

## 🛠️ **Xcode Integration**

### **Open in Xcode:**
```bash
open ios/Runner.xcworkspace
```

### **Build in Xcode:**
1. Open `ios/Runner.xcworkspace`
2. Select Runner target
3. Choose device/simulator
4. Press Cmd+R to build and run

---

## 📋 **Common Solutions Checklist**

### **Before Building:**
- [ ] Flutter SDK is up to date
- [ ] Xcode is up to date
- [ ] iOS deployment target is set to 13.0+
- [ ] All dependencies are installed
- [ ] Pods are installed correctly

### **Build Issues:**
- [ ] Clean project with `flutter clean`
- [ ] Remove derived data
- [ ] Reinstall dependencies
- [ ] Check for conflicting packages
- [ ] Verify iOS configuration

### **Runtime Issues:**
- [ ] Check OAuth configuration
- [ ] Verify Firebase setup
- [ ] Test on different simulators
- [ ] Check console logs

---

## 🎯 **Quick Fix Commands**

### **Complete Reset:**
```bash
# Clean everything
flutter clean
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ios/build
rm -rf ios/Pods

# Reinstall everything
flutter pub get
cd ios && pod install && cd ..

# Run
flutter run -d ios
```

### **Pod Reset:**
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
```

### **Flutter Reset:**
```bash
flutter clean
flutter pub get
```

---

## 📞 **Getting Help**

### **If Issues Persist:**
1. Check Flutter GitHub issues
2. Check iOS-specific Flutter issues
3. Verify Xcode and iOS SDK versions
4. Test with a minimal Flutter project
5. Check for package conflicts

### **Useful Resources:**
- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [CocoaPods Troubleshooting](https://guides.cocoapods.org/using/troubleshooting.html)
- [Xcode Build Issues](https://developer.apple.com/documentation/xcode/build-settings)

---

*Last Updated: December 2024* 