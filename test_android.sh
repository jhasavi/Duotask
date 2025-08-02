#!/bin/bash

echo "🤖 Android OAuth Test Script"
echo "============================"
echo ""

# Check if Android device/emulator is available
echo "📱 Checking Android devices..."
flutter devices | grep android

if [ $? -eq 0 ]; then
    echo "✅ Android device found"
    echo ""
    echo "🚀 Starting Android OAuth test..."
    echo "This will:"
    echo "1. Launch the app on Android"
    echo "2. Test Google Sign-In"
    echo "3. Check for redirect_uri_mismatch errors"
    echo ""
    echo "Press Ctrl+C to stop the test"
    echo ""
    
    flutter run -d android
else
    echo "❌ No Android device found"
    echo ""
    echo "🔄 Attempting to start Android emulator..."
    
    # Check if Android emulators are available
    echo "📋 Available Android emulators:"
    flutter emulators
    
    # Try to start the first available emulator
    echo ""
    echo "🚀 Starting first available emulator..."
    
    # Get the first available emulator ID
    EMULATOR_ID=$(flutter emulators | grep -E "^[a-zA-Z0-9_-]+" | head -1 | awk '{print $1}')
    
    if [ -n "$EMULATOR_ID" ]; then
        echo "✅ Starting emulator: $EMULATOR_ID"
        flutter emulators --launch $EMULATOR_ID
        
        # Wait for emulator to start
        echo "⏳ Waiting for emulator to start (30 seconds)..."
        sleep 30
        
        # Check if emulator is now available
        echo "🔍 Checking if emulator is ready..."
        flutter devices | grep android
        
        if [ $? -eq 0 ]; then
            echo "✅ Android emulator is ready!"
            echo ""
            echo "🚀 Starting Android OAuth test..."
            echo "This will:"
            echo "1. Launch the app on Android"
            echo "2. Test Google Sign-In"
            echo "3. Check for redirect_uri_mismatch errors"
            echo ""
            echo "Press Ctrl+C to stop the test"
            echo ""
            
            flutter run -d android
        else
            echo "❌ Emulator failed to start properly"
            echo ""
            echo "Manual steps:"
            echo "1. Start Android Studio"
            echo "2. Open AVD Manager"
            echo "3. Start an Android emulator"
            echo "4. Run: flutter run -d android"
            echo ""
            echo "Or connect a physical Android device via USB"
        fi
    else
        echo "❌ No Android emulators found"
        echo ""
        echo "To create an Android emulator:"
        echo "1. Start Android Studio"
        echo "2. Open AVD Manager"
        echo "3. Click 'Create Virtual Device'"
        echo "4. Choose a device (e.g., Pixel 4)"
        echo "5. Choose a system image (e.g., API 34)"
        echo "6. Click 'Finish'"
        echo ""
        echo "Then run this script again: ./test_android.sh"
    fi
fi 