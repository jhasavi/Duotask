#!/bin/bash

echo "🚀 Setting up Android development for DuoTask..."

# Check if Android Studio is installed
if [ ! -d "/Applications/Android Studio.app" ]; then
    echo "❌ Android Studio not found. Please install Android Studio first."
    echo "Download from: https://developer.android.com/studio"
    exit 1
fi

echo "✅ Android Studio found"

# Set environment variables
echo "🔧 Setting up environment variables..."

# Check if variables already exist
if ! grep -q "ANDROID_HOME" ~/.zshrc; then
    echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
    echo 'export PATH=$PATH:$ANDROID_HOME/emulator' >> ~/.zshrc
    echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.zshrc
    echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin' >> ~/.zshrc
    echo "✅ Environment variables added to ~/.zshrc"
else
    echo "✅ Environment variables already exist"
fi

# Reload shell configuration
source ~/.zshrc

echo ""
echo "📋 Next Steps:"
echo "1. Open Android Studio: open -a 'Android Studio'"
echo "2. Go to Tools → SDK Manager → SDK Tools tab"
echo "3. Install these components:"
echo "   - Android SDK Command-line Tools (latest)"
echo "   - Android SDK Platform-Tools"
echo "   - Android SDK Build-Tools"
echo "   - Android Emulator"
echo "   - Android SDK Tools"
echo "4. After installation, run: flutter doctor --android-licenses"
echo "5. Create an Android Virtual Device (AVD) in Android Studio"
echo "6. Test with: flutter run -d android"
echo ""
echo "🎯 For detailed instructions, see: ANDROID_SETUP_GUIDE.md" 