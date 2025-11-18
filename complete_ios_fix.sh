#!/bin/bash

# Complete iOS Fix Script
# This script will fix all iOS version issues and get the app running

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header "DUOTASK COMPREHENSIVE iOS FIX"

print_step "1. Checking available iOS versions..."
echo "Available iOS runtimes:"
xcrun simctl list runtimes | grep iOS

print_step "2. Cleaning all build artifacts..."
flutter clean
rm -rf ios/build
rm -rf ios/.symlinks
rm -rf ios/Pods
rm -rf ios/Podfile.lock

print_step "3. Regenerating Flutter iOS configuration..."
flutter pub get

print_step "4. Reinstalling iOS dependencies..."
cd ios
pod install --repo-update
cd ..

print_step "5. Checking available simulators..."
xcrun simctl list devices available | grep iPhone

print_step "6. Starting iPhone 15 simulator..."
DEVICE_ID="FA637029-C525-4101-8C79-05EC23273EB2"
# First shutdown all simulators to avoid conflicts
print_step "Shutting down any running simulators..."
xcrun simctl shutdown all 2>/dev/null || true
sleep 3

# Now boot the iPhone 15 simulator
print_step "Booting iPhone 15 simulator..."
if xcrun simctl boot "$DEVICE_ID" 2>&1; then
    print_success "Simulator booted successfully"
    open -a Simulator
else
    print_warning "Simulator may already be booted or in transition state"
    open -a Simulator
fi

print_step "7. Waiting for simulator to be ready..."
sleep 5

print_step "8. Attempting iOS build with correct target..."
# Try multiple approaches
echo "Approach 1: Using device ID..."
if flutter run -d "$DEVICE_ID" --debug; then
    print_success "iOS app launched successfully with device ID!"
    exit 0
fi

echo "Approach 2: Using generic iOS target..."
if flutter run -d ios --debug; then
    print_success "iOS app launched successfully with generic target!"
    exit 0
fi

echo "Approach 3: Opening Xcode for manual build..."
open ios/Runner.xcworkspace

print_error "Automatic launch failed. Manual steps:"
echo ""
echo "In Xcode that just opened:"
echo "1. Select 'iPhone 15' from the device menu (top left)"
echo "2. Click the Play button (▶) to build and run"
echo "3. If prompted about signing, select 'Automatically manage signing'"
echo "4. Choose your Apple ID or team if available"
echo ""

print_step "Meanwhile, you can continue testing the web app:"
echo "🌐 Web App: http://localhost:8080"
echo ""

print_success "Setup complete! Check Xcode or try manual flutter run."