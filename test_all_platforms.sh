#!/bin/bash

# DuoTask Multi-Platform Testing Script
# This script launches the app on Web (Chrome), iOS Simulator, and Android Emulator
# and provides guided testing for pairing and other features

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for user input
wait_for_user() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Function to check Flutter installation
check_flutter() {
    print_step "Checking Flutter installation..."
    if ! command_exists flutter; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    flutter --version
    print_success "Flutter is installed"
}

# Function to install dependencies
install_dependencies() {
    print_step "Installing Flutter dependencies..."
    flutter pub get
    print_success "Dependencies installed"
}

# Function to check iOS setup
check_ios_setup() {
    print_step "Checking iOS setup..."
    
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_warning "iOS development requires macOS. Skipping iOS setup."
        return 1
    fi
    
    if ! command_exists xcodebuild; then
        print_warning "Xcode is not installed. iOS testing will be skipped."
        return 1
    fi
    
    # Check if iOS simulator is available
    if ! xcrun simctl list devices available | grep -q "iPhone"; then
        print_warning "No iOS simulators available. Please install iOS simulators in Xcode."
        return 1
    fi
    
    print_success "iOS setup is ready"
    return 0
}

# Function to check Android setup
check_android_setup() {
    print_step "Checking Android setup..."
    
    if [ -z "$ANDROID_HOME" ]; then
        print_warning "ANDROID_HOME is not set. Trying common locations..."
        
        # Try common Android SDK locations
        if [ -d "$HOME/Library/Android/sdk" ]; then
            export ANDROID_HOME="$HOME/Library/Android/sdk"
        elif [ -d "$HOME/Android/Sdk" ]; then
            export ANDROID_HOME="$HOME/Android/Sdk"
        else
            print_error "Android SDK not found. Please install Android Studio and set ANDROID_HOME."
            return 1
        fi
    fi
    
    if [ ! -f "$ANDROID_HOME/emulator/emulator" ]; then
        print_error "Android emulator not found in $ANDROID_HOME/emulator/"
        return 1
    fi
    
    print_success "Android setup is ready"
    return 0
}

# Function to start iOS simulator
start_ios_simulator() {
    print_step "Starting iOS Simulator..."
    
    # Check if a simulator is already booted
    local booted_simulator
    booted_simulator=$(xcrun simctl list devices | grep "Booted" | grep iPhone | head -1)
    
    if [ ! -z "$booted_simulator" ]; then
        print_info "iOS Simulator already running: $(echo "$booted_simulator" | cut -d'(' -f1 | xargs)"
        print_success "iOS Simulator ready"
        return 0
    fi
    
    # Get available iOS simulators
    local ios_devices
    ios_devices=$(xcrun simctl list devices available | grep iPhone | head -1)
    
    if [ -z "$ios_devices" ]; then
        print_error "No iOS simulators found"
        return 1
    fi
    
    # Extract device ID
    local device_id
    device_id=$(echo "$ios_devices" | grep -o '\([A-F0-9-]*\)' | head -1)
    device_id=${device_id//[()]/}  # Remove parentheses
    
    print_info "Starting iOS Simulator with device ID: $device_id"
    xcrun simctl boot "$device_id" 2>/dev/null || true
    open -a Simulator
    
    # Wait for simulator to be ready
    print_info "Waiting for iOS Simulator to boot..."
    local timeout=60
    local elapsed=0
    
    while ! xcrun simctl list devices | grep "$device_id" | grep -q "Booted"; do
        if [ $elapsed -ge $timeout ]; then
            print_error "iOS Simulator failed to start within $timeout seconds"
            return 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    print_success "iOS Simulator started and ready"
    sleep 3
}

# Function to start Android emulator
start_android_emulator() {
    print_step "Starting Android Emulator..."
    
    # Get list of available AVDs
    local avds
    avds=$("$ANDROID_HOME/emulator/emulator" -list-avds)
    
    if [ -z "$avds" ]; then
        print_error "No Android Virtual Devices (AVDs) found."
        print_info "Please create an AVD in Android Studio: Tools > AVD Manager"
        return 1
    fi
    
    # Use the first available AVD
    local avd_name
    avd_name=$(echo "$avds" | head -1)
    
    print_info "Starting Android Emulator with AVD: $avd_name"
    "$ANDROID_HOME/emulator/emulator" -avd "$avd_name" -no-audio -no-boot-anim &
    
    print_info "Waiting for Android Emulator to boot..."
    local timeout=120
    local elapsed=0
    
    while ! adb devices | grep -q "emulator.*device"; do
        if [ $elapsed -ge $timeout ]; then
            print_error "Android Emulator failed to start within $timeout seconds"
            return 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    print_success "Android Emulator started and ready"
}

# Function to launch web app
launch_web_app() {
    print_step "Launching Web App in Chrome..."
    
    # Kill any existing flutter process on port 5000
    lsof -ti:5000 | xargs kill -9 2>/dev/null || true
    
    # Launch web app in background
    flutter run -d chrome --web-port 5000 --release &
    WEB_PID=$!
    
    print_info "Web app is starting on http://localhost:5000"
    print_info "Process ID: $WEB_PID"
    
    # Wait for the app to start
    sleep 10
    
    print_success "Web app launched in Chrome"
}

# Function to launch iOS app
launch_ios_app() {
    print_step "Launching iOS App..."
    
    # Get the booted iOS device ID
    local ios_device_id
    ios_device_id=$(xcrun simctl list devices | grep "Booted" | grep iPhone | head -1 | grep -o '([A-F0-9-]*)')
    ios_device_id=${ios_device_id//[()]/}  # Remove parentheses
    
    if [ -z "$ios_device_id" ]; then
        print_error "No booted iOS simulator found. Starting one first..."
        start_ios_simulator
        sleep 5
        ios_device_id=$(xcrun simctl list devices | grep "Booted" | grep iPhone | head -1 | grep -o '([A-F0-9-]*)')
        ios_device_id=${ios_device_id//[()]/}  # Remove parentheses
    fi
    
    print_info "Using iOS device: $ios_device_id"
    
    # Launch iOS app in background with specific device ID
    flutter run -d "$ios_device_id" --release &
    IOS_PID=$!
    
    print_info "iOS app is starting on simulator"
    print_info "Process ID: $IOS_PID"
    
    # Wait for the app to start
    sleep 15
    
    print_success "iOS app launched on simulator"
}

# Function to launch Android app
launch_android_app() {
    print_step "Launching Android App..."
    
    # Launch Android app in background
    flutter run -d android --release &
    ANDROID_PID=$!
    
    print_info "Android app is starting on emulator"
    print_info "Process ID: $ANDROID_PID"
    
    # Wait for the app to start
    sleep 15
    
    print_success "Android app launched on emulator"
}

# Function to display testing instructions
show_testing_instructions() {
    print_header "TESTING INSTRUCTIONS"
    
    echo -e "${PURPLE}🎯 TESTING WORKFLOW${NC}"
    echo "1. Test authentication on each platform"
    echo "2. Create a pairing between two platforms"
    echo "3. Test task creation and real-time sync"
    echo "4. Test all task features"
    echo ""
    
    echo -e "${PURPLE}📱 PLATFORMS RUNNING:${NC}"
    [ ! -z "$WEB_PID" ] && echo "  🌐 Web: http://localhost:5000 (Chrome)"
    [ ! -z "$IOS_PID" ] && echo "  📱 iOS: Simulator"
    [ ! -z "$ANDROID_PID" ] && echo "  🤖 Android: Emulator"
    echo ""
    
    echo -e "${PURPLE}🔐 AUTHENTICATION TEST:${NC}"
    echo "  • Try Google Sign-In on web platform first"
    echo "  • Then try email/password registration"
    echo "  • Verify login works on all platforms"
    echo ""
    
    echo -e "${PURPLE}🤝 PAIRING TEST:${NC}"
    echo "  • Platform 1: Tap profile icon → Generate pairing code"
    echo "  • Platform 2: Tap profile icon → Enter pairing code"
    echo "  • Verify both platforms show \"Paired with [name]\""
    echo ""
    
    echo -e "${PURPLE}📋 TASK MANAGEMENT TEST:${NC}"
    echo "  • Create task: Tap + button or type in text field"
    echo "  • Try natural language: \"Grocery shopping @6pm\""
    echo "  • Claim task: Tap bubble (orange → blue)"
    echo "  • Complete task: Tap claimed bubble (blue → green)"
    echo "  • Set priority: Long press → Mark as urgent"
    echo ""
    
    echo -e "${PURPLE}⚡ REAL-TIME SYNC TEST:${NC}"
    echo "  • Create task on Platform 1"
    echo "  • Verify it appears on Platform 2 instantly"
    echo "  • Claim task on Platform 2"
    echo "  • Verify status changes on Platform 1"
    echo ""
    
    echo -e "${PURPLE}🎨 VISUAL INDICATORS:${NC}"
    echo "  • Orange bubbles: Unclaimed tasks"
    echo "  • Blue bubbles: Claimed tasks"
    echo "  • Green bubbles: Completed tasks"
    echo "  • Red border: Urgent tasks"
    echo "  • Size varies by status"
    echo ""
    
    echo -e "${PURPLE}📱 MOBILE-SPECIFIC TESTS:${NC}"
    echo "  • Test device rotation"
    echo "  • Test background/foreground transitions"
    echo "  • Test notifications (if enabled)"
    echo ""
    
    print_warning "IMPORTANT: Use different email addresses for each platform if testing pairing!"
}

# Function to monitor running processes
monitor_processes() {
    print_header "PROCESS MONITORING"
    
    echo -e "${PURPLE}Running Processes:${NC}"
    [ ! -z "$WEB_PID" ] && echo "  Web App PID: $WEB_PID"
    [ ! -z "$IOS_PID" ] && echo "  iOS App PID: $IOS_PID"
    [ ! -z "$ANDROID_PID" ] && echo "  Android App PID: $ANDROID_PID"
    
    echo ""
    echo -e "${YELLOW}To stop processes manually:${NC}"
    [ ! -z "$WEB_PID" ] && echo "  Web: kill $WEB_PID"
    [ ! -z "$IOS_PID" ] && echo "  iOS: kill $IOS_PID"
    [ ! -z "$ANDROID_PID" ] && echo "  Android: kill $ANDROID_PID"
    
    echo ""
    echo -e "${YELLOW}Or use: pkill -f flutter${NC}"
}

# Function to cleanup processes
cleanup() {
    print_header "CLEANING UP"
    
    [ ! -z "$WEB_PID" ] && kill "$WEB_PID" 2>/dev/null && print_info "Stopped web app"
    [ ! -z "$IOS_PID" ] && kill "$IOS_PID" 2>/dev/null && print_info "Stopped iOS app"
    [ ! -z "$ANDROID_PID" ] && kill "$ANDROID_PID" 2>/dev/null && print_info "Stopped Android app"
    
    # Kill any remaining flutter processes
    pkill -f flutter 2>/dev/null || true
    
    print_success "Cleanup completed"
}

# Trap to cleanup on exit
trap cleanup EXIT

# Main execution
main() {
    print_header "DUOTASK MULTI-PLATFORM TESTING"
    
    # Pre-flight checks
    check_flutter
    install_dependencies
    
    print_info "Checking platform availability..."
    
    # Check what platforms are available
    local ios_available=false
    local android_available=false
    
    if check_ios_setup; then
        ios_available=true
    fi
    
    if check_android_setup; then
        android_available=true
    fi
    
    # Start platforms
    print_header "LAUNCHING PLATFORMS"
    
    # Always try to launch web (most reliable)
    launch_web_app
    
    # Start iOS if available
    if [ "$ios_available" = true ]; then
        start_ios_simulator
        wait_for_user
        launch_ios_app
    fi
    
    # Start Android if available
    if [ "$android_available" = true ]; then
        start_android_emulator
        wait_for_user
        launch_android_app
    fi
    
    # Show testing instructions
    show_testing_instructions
    
    # Monitor processes
    wait_for_user
    monitor_processes
    
    # Keep script running until user presses Ctrl+C
    print_header "TESTING IN PROGRESS"
    echo -e "${GREEN}All platforms are running!${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop all processes and exit${NC}"
    echo ""
    
    # Wait indefinitely
    while true; do
        sleep 10
        
        # Check if processes are still running
        [ ! -z "$WEB_PID" ] && ! kill -0 "$WEB_PID" 2>/dev/null && WEB_PID=""
        [ ! -z "$IOS_PID" ] && ! kill -0 "$IOS_PID" 2>/dev/null && IOS_PID=""
        [ ! -z "$ANDROID_PID" ] && ! kill -0 "$ANDROID_PID" 2>/dev/null && ANDROID_PID=""
        
        # If all processes died, exit
        if [ -z "$WEB_PID" ] && [ -z "$IOS_PID" ] && [ -z "$ANDROID_PID" ]; then
            print_warning "All app processes have stopped"
            break
        fi
    done
}

# Run main function
main "$@"