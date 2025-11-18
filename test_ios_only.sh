#!/bin/bash

# iOS-specific testing script for DuoTask
# Use this to test and troubleshoot iOS simulator issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header "DUOTASK iOS TESTING"

print_step "Checking iOS development setup..."
if ! command -v xcodebuild >/dev/null 2>&1; then
    print_error "Xcode is not installed"
    exit 1
fi
print_success "Xcode is available"

print_step "Checking available iOS simulators..."
xcrun simctl list devices available | grep iPhone

print_step "Checking currently booted simulators..."
booted=$(xcrun simctl list devices | grep "Booted" | grep iPhone || echo "None")
if [ "$booted" = "None" ]; then
    print_info "No iOS simulators currently booted"
else
    print_info "Booted simulator: $booted"
fi

print_step "Checking Flutter iOS capabilities..."
flutter doctor | grep -A5 "Xcode"

print_step "Listing all Flutter devices..."
flutter devices

print_step "Installing Flutter dependencies..."
flutter pub get

print_step "Starting iOS simulator if needed..."
if ! xcrun simctl list devices | grep "Booted" | grep -q iPhone; then
    print_info "Starting first available iPhone simulator..."
    device_id=$(xcrun simctl list devices available | grep iPhone | head -1 | grep -o '\([A-F0-9-]*\)' | head -1)
    device_id=${device_id//[()]/}
    
    print_info "Using device ID: $device_id"
    xcrun simctl boot "$device_id" 2>/dev/null || true
    open -a Simulator
    
    print_info "Waiting for simulator to boot..."
    timeout=60
    elapsed=0
    while ! xcrun simctl list devices | grep "$device_id" | grep -q "Booted"; do
        if [ $elapsed -ge $timeout ]; then
            print_error "Simulator failed to boot within $timeout seconds"
            exit 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        echo -n "."
    done
    echo ""
    print_success "Simulator booted successfully"
else
    print_success "Simulator already running"
fi

print_step "Getting booted iOS device ID for Flutter..."
ios_device_id=$(xcrun simctl list devices | grep "Booted" | grep iPhone | head -1 | grep -o '([A-F0-9-]*)')
ios_device_id=${ios_device_id//[()]/}
print_info "iOS Device ID: $ios_device_id"

print_step "Verifying Flutter can see the iOS device..."
if flutter devices | grep -q "$ios_device_id"; then
    print_success "Flutter can see the iOS simulator"
else
    print_error "Flutter cannot see the iOS simulator"
    print_info "Try running: flutter doctor"
    exit 1
fi

print_header "LAUNCHING DUOTASK ON IOS"
print_info "Starting DuoTask on iOS simulator..."
print_info "Device ID: $ios_device_id"

# Clean iOS build first
print_step "Cleaning iOS build..."
cd ios
rm -rf Pods Podfile.lock build
cd ..
flutter clean
flutter pub get

print_step "Installing iOS dependencies..."
cd ios
pod install
cd ..

print_step "Launching app on iOS..."
flutter run -d "$ios_device_id" --debug

print_success "iOS testing complete!"