# Flutter & Android Development Environment Configuration
# Generated for DuoTask project

# =============================================================================
# FLUTTER & DART CONFIGURATION
# =============================================================================

# Flutter SDK path (adjust if needed)
export FLUTTER_ROOT=/usr/local/bin/flutter
export PATH=$PATH:$FLUTTER_ROOT/bin

# Dart SDK path
export DART_SDK=/usr/local/bin/dart
export PATH=$PATH:$DART_SDK/bin

# =============================================================================
# ANDROID DEVELOPMENT CONFIGURATION
# =============================================================================

# Android SDK paths
export ANDROID_HOME=$HOME/Library/Android/sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export ANDROID_AVD_HOME=$HOME/.android/avd

# Android SDK tools
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin

# =============================================================================
# IOS DEVELOPMENT CONFIGURATION
# =============================================================================

# Xcode command line tools
export PATH=$PATH:/Applications/Xcode.app/Contents/Developer/usr/bin
export PATH=$PATH:/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin

# iOS Simulator
export PATH=$PATH:/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app/Contents/MacOS

# =============================================================================
# DEVELOPMENT TOOLS
# =============================================================================

# Homebrew
export PATH="/opt/homebrew/bin:$PATH"
export PATH="/opt/homebrew/sbin:$PATH"

# Node.js (if needed for web development)
export PATH=$PATH:/usr/local/bin/node
export PATH=$PATH:/usr/local/bin/npm

# Git configuration
export GIT_EDITOR=nano

# =============================================================================
# PROJECT-SPECIFIC CONFIGURATION
# =============================================================================

# DuoTask project environment
export DUOTASK_PROJECT_ROOT=$HOME/task_bubble

# Supabase configuration (if using environment variables)
export SUPABASE_URL=https://xqhlnuvpogiolzkucupt.supabase.co
export SUPABASE_ANON_KEY=your-anon-key-here

# =============================================================================
# ALIASES FOR DEVELOPMENT
# =============================================================================

# Flutter aliases
alias f='flutter'
alias fd='flutter doctor'
alias fg='flutter pub get'
alias fc='flutter clean'
alias fb='flutter build'
alias fr='flutter run'
alias ft='flutter test'

# Android aliases
alias adb='$ANDROID_HOME/platform-tools/adb'
alias emulator='$ANDROID_HOME/emulator/emulator'
alias avdmanager='$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager'
alias sdkmanager='$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager'

# iOS aliases
alias simctl='xcrun simctl'
alias xcodebuild='xcrun xcodebuild'

# Project aliases
alias duotask='cd $DUOTASK_PROJECT_ROOT'
alias ios='flutter run -d "iPhone 16 Plus"'
alias android='flutter run -d android'
alias web='flutter run -d chrome'
alias mac='flutter run -d macos'

# =============================================================================
# DEVELOPMENT FUNCTIONS
# =============================================================================

# Function to check Flutter environment
flutter_check() {
    echo "🔍 Checking Flutter environment..."
    flutter doctor -v
}

# Function to clean and rebuild
flutter_clean_build() {
    echo "🧹 Cleaning Flutter project..."
    flutter clean
    flutter pub get
    echo "✅ Clean build completed!"
}

# Function to run on all platforms
flutter_all() {
    echo "🚀 Running Flutter on all platforms..."
    echo "📱 iOS..."
    flutter run -d "iPhone 16 Plus" &
    echo "🤖 Android..."
    flutter run -d android &
    echo "🌐 Web..."
    flutter run -d chrome &
    echo "💻 macOS..."
    flutter run -d macos &
}

# Function to check Android devices
android_devices() {
    echo "📱 Checking Android devices..."
    flutter devices
    echo ""
    echo "🤖 Available Android emulators:"
    flutter emulators
}

# Function to create Android emulator
create_android_emulator() {
    echo "🤖 Creating Android emulator..."
    flutter emulators --create --name pixel_7_api_34
    echo "✅ Android emulator created!"
}

# Function to launch Android emulator
launch_android_emulator() {
    echo "🚀 Launching Android emulator..."
    flutter emulators --launch pixel_7_api_34
}

# =============================================================================
# SHELL CONFIGURATION
# =============================================================================

# Enable command history
HISTCONTROL=ignoreboth
HISTSIZE=10000
HISTFILESIZE=20000

# Enable command completion
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# Set prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# =============================================================================
# ENVIRONMENT VERIFICATION
# =============================================================================

# Verify environment on startup
echo "🚀 Flutter & Android development environment loaded!"
echo "📱 Available commands:"
echo "  - flutter_check: Check Flutter environment"
echo "  - flutter_clean_build: Clean and rebuild project"
echo "  - android_devices: List Android devices"
echo "  - create_android_emulator: Create Android emulator"
echo "  - launch_android_emulator: Launch Android emulator"
echo "  - ios: Run on iOS simulator"
echo "  - android: Run on Android"
echo "  - web: Run on web"
echo "  - mac: Run on macOS"
echo "" 