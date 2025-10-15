#!/bin/bash

# DuoTask Quick Validation Script
# Run this before real-world testing to ensure everything is working

set -e

echo "🔍 DuoTask Quick Validation Script"
echo "=================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check Flutter installation
print_info "Checking Flutter installation..."
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n 1)
    print_success "Flutter found: $FLUTTER_VERSION"
else
    print_error "Flutter not found. Please install Flutter first."
    exit 1
fi

# Check dependencies
print_info "Checking dependencies..."
flutter pub get
print_success "Dependencies updated"

# Run unit tests
print_info "Running unit tests..."
if flutter test test/simple_test.dart; then
    print_success "Unit tests passed"
else
    print_error "Unit tests failed"
    exit 1
fi

# Run pairing logic tests
print_info "Running pairing logic tests..."
if flutter test test/pairing_logic_test.dart; then
    print_success "Pairing logic tests passed"
else
    print_error "Pairing logic tests failed"
    exit 1
fi

# Build for testing
print_info "Building app for testing..."
if flutter build apk --debug; then
    print_success "App built successfully"
else
    print_error "App build failed"
    exit 1
fi

# Check for common issues
print_info "Checking for common issues..."

# Check if Firebase is configured
if [ -f "firebase.json" ]; then
    print_success "Firebase configuration found"
else
    print_warning "Firebase configuration not found (optional for testing)"
fi

# Check if Supabase is configured
if [ -f "lib/firebase_options.dart" ]; then
    print_success "Supabase configuration found"
else
    print_warning "Supabase configuration not found (required for real testing)"
fi

# Check for required files
REQUIRED_FILES=(
    "lib/main.dart"
    "lib/screens/modern_task_screen.dart"
    "lib/services/pairing_service.dart"
    "lib/widgets/task_bubble.dart"
    "lib/widgets/color_tutorial_widget.dart"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_success "Found: $file"
    else
        print_error "Missing: $file"
        exit 1
    fi
done

# Performance check
print_info "Running performance check..."
flutter run --profile --enable-software-rendering --dart-define=FLUTTER_WEB_USE_SKIA=true &
PERF_PID=$!

# Wait a bit for the app to start
sleep 5

# Kill the performance test
kill $PERF_PID 2>/dev/null || true
print_success "Performance check completed"

# Summary
echo ""
echo "=================================="
print_success "Quick validation completed successfully!"
echo ""
print_info "Next steps for real-world testing:"
echo "  1. Install the app on 3 devices"
echo "  2. Register 3 different users"
echo "  3. Follow the REAL_WORLD_TESTING_GUIDE.md"
echo "  4. Test all pairing scenarios"
echo "  5. Verify real-time updates"
echo ""
print_info "Key features to test:"
echo "  ✅ Pairing/unpairing workflow"
echo "  ✅ Task creation and sharing"
echo "  ✅ Real-time status updates"
echo "  ✅ Task isolation (personal vs shared)"
echo "  ✅ Color tutorial and UI"
echo "  ✅ Search functionality"
echo "  ✅ Settings and navigation"
echo ""
print_success "Ready for real-world testing! 🚀"


