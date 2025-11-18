#!/bin/bash

# Simple iOS Launch Script - Avoids simulator boot conflicts

echo "=================================="
echo "SIMPLE iOS SIMULATOR LAUNCHER"
echo "=================================="

cd /Users/sanjeevjha/duo/duotask

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[1/5]${NC} Shutting down all simulators..."
xcrun simctl shutdown all 2>/dev/null
sleep 2

echo -e "${BLUE}[2/5]${NC} Opening Simulator app..."
open -a Simulator
sleep 5

echo -e "${BLUE}[3/5]${NC} Booting iPhone 15..."
xcrun simctl boot "iPhone 15" 2>&1
sleep 5

echo -e "${BLUE}[4/5]${NC} Cleaning Flutter project..."
flutter clean > /dev/null 2>&1
flutter pub get > /dev/null 2>&1

echo -e "${BLUE}[5/5]${NC} Launching DuoTask app..."
echo ""
echo -e "${YELLOW}Note: If Flutter build fails, use Xcode instead:${NC}"
echo "  1. Open: ios/Runner.xcworkspace"
echo "  2. Select 'iPhone 15' device"
echo "  3. Click ▶ (Play button)"
echo ""

# Try to launch with Flutter
flutter run -d "iPhone 15" --debug

# If that fails, open Xcode
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Flutter launch failed. Opening Xcode...${NC}"
    open ios/Runner.xcworkspace
    echo ""
    echo -e "${GREEN}Build manually in Xcode:${NC}"
    echo "  • Select 'iPhone 15' from device dropdown"
    echo "  • Click ▶ button to build and run"
    echo ""
fi
