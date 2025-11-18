#!/bin/bash

echo "=================================="
echo "DUOTASK ANDROID EMULATOR SETUP"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Android SDK is available
print_step "1. Checking Android SDK installation..."
if ! command -v adb &> /dev/null; then
    print_error "Android SDK not found. Please install Android Studio first."
    exit 1
fi

# Check for available AVDs
print_step "2. Checking available Android Virtual Devices (AVDs)..."
avd_list=$(emulator -list-avds 2>/dev/null)

if [ -z "$avd_list" ]; then
    print_warning "No Android Virtual Devices found."
    print_step "Creating a new AVD..."
    
    # Try to create an AVD automatically
    echo "Available system images:"
    avdmanager list targets | grep -E "(android-|Google APIs)"
    
    print_step "Attempting to create Pixel_7_API_34 AVD..."
    echo "no" | avdmanager create avd -n "Pixel_7_API_34" -k "system-images;android-34;google_apis;x86_64" --device "pixel_7" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "Created Pixel_7_API_34 AVD"
        avd_name="Pixel_7_API_34"
    else
        print_error "Failed to create AVD. Please create one manually in Android Studio:"
        echo "1. Open Android Studio"
        echo "2. Go to Tools > AVD Manager"
        echo "3. Create Virtual Device"
        echo "4. Choose Pixel 7, API 34 (Android 14)"
        echo "5. Name it 'DuoTask_Emulator'"
        exit 1
    fi
else
    echo "Found AVDs:"
    echo "$avd_list"
    avd_name=$(echo "$avd_list" | head -1)
    print_success "Using AVD: $avd_name"
fi

# Start the Android emulator
print_step "3. Starting Android emulator ($avd_name)..."
emulator -avd "$avd_name" -no-audio -no-window &
emulator_pid=$!

print_step "4. Waiting for emulator to boot..."
adb wait-for-device
sleep 10

# Check if emulator is ready
while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
    echo "Waiting for emulator to finish booting..."
    sleep 5
done

print_success "Android emulator is ready!"

# Try to build and run the Flutter app
print_step "5. Building and running Flutter app on Android..."
cd /Users/sanjeevjha/duo/duotask

flutter clean
flutter pub get

print_step "6. Launching DuoTask on Android emulator..."
flutter run --debug &
flutter_pid=$!

print_success "Android setup complete!"
echo ""
echo "🤖 Android Emulator: Started successfully"
echo "📱 DuoTask App: Building and launching..."
echo ""
echo "Next: Use test_all_platforms.sh to test all three platforms together"

# Keep script running to monitor processes
echo "Press Ctrl+C to stop the emulator"
wait $flutter_pid