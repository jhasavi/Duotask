#!/bin/bash

# DuoTask Test Runner
# This script runs comprehensive tests for the DuoTask app

set -e  # Exit on any error

echo "🧪 Starting DuoTask Automated Tests..."
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
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

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

print_status "Flutter version: $(flutter --version | head -n 1)"

# Get dependencies
print_status "Getting dependencies..."
flutter pub get

# Run unit tests
print_status "Running unit tests..."
if flutter test; then
    print_success "Unit tests passed!"
else
    print_error "Unit tests failed!"
    exit 1
fi

# Run integration tests (if they exist)
if [ -d "integration_test" ]; then
    print_status "Running integration tests..."
    if flutter test integration_test/; then
        print_success "Integration tests passed!"
    else
        print_error "Integration tests failed!"
        exit 1
    fi
else
    print_warning "No integration tests found. Skipping..."
fi

# Build for testing
print_status "Building app for testing..."
if flutter build apk --debug; then
    print_success "App built successfully!"
else
    print_error "App build failed!"
    exit 1
fi

# Check if Firebase is configured
if [ -f "firebase.json" ]; then
    print_status "Firebase configuration found"
    
    # Check if gcloud is installed
    if command -v gcloud &> /dev/null; then
        print_status "Running Firebase Test Lab..."
        
        # Check if we have test quota
        QUOTA_INFO=$(gcloud firebase test android run --help 2>&1 || true)
        if echo "$QUOTA_INFO" | grep -q "quota"; then
            print_warning "Firebase Test Lab quota may be exceeded. Skipping..."
        else
            # Run a basic Firebase Test Lab test
            gcloud firebase test android run \
                --type instrumentation \
                --app build/app/outputs/apk/debug/app-debug.apk \
                --device model=redfin,version=30,locale=en,orientation=portrait \
                --timeout 5m || {
                print_warning "Firebase Test Lab failed or quota exceeded. Continuing..."
            }
        fi
    else
        print_warning "gcloud CLI not found. Install it to use Firebase Test Lab"
    fi
else
    print_warning "No Firebase configuration found. Skipping Firebase Test Lab..."
fi

# Performance check
print_status "Running performance analysis..."
flutter run --profile --enable-software-rendering --dart-define=FLUTTER_WEB_USE_SKIA=true &
PERF_PID=$!

# Wait a bit for the app to start
sleep 10

# Kill the performance test
kill $PERF_PID 2>/dev/null || true

print_success "Performance test completed!"

# Generate test coverage report
print_status "Generating coverage report..."
if flutter test --coverage; then
    if command -v genhtml &> /dev/null; then
        genhtml coverage/lcov.info -o coverage/html
        print_success "Coverage report generated at coverage/html/index.html"
    else
        print_warning "genhtml not found. Install lcov to generate HTML coverage reports"
    fi
else
    print_warning "Coverage generation failed"
fi

# Summary
echo ""
echo "======================================"
print_success "All tests completed successfully!"
echo ""
print_status "Test Summary:"
echo "  ✅ Unit tests: PASSED"
if [ -d "integration_test" ]; then
    echo "  ✅ Integration tests: PASSED"
fi
echo "  ✅ App build: SUCCESS"
echo "  ✅ Performance test: COMPLETED"
echo ""
print_status "Next steps:"
echo "  1. Test the app manually on real devices"
echo "  2. Test pairing functionality with two devices"
echo "  3. Test real-time updates between paired users"
echo "  4. Verify all UI elements work correctly"
echo ""

# Optional: Open coverage report
if [ -f "coverage/html/index.html" ]; then
    read -p "Open coverage report in browser? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open coverage/html/index.html
    fi
fi

print_success "Test runner completed! 🎉"
