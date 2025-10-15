#!/bin/bash

# DuoTask Deployment Script
# This script automates the build and deployment process for DuoTask

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="DuoTask"
VERSION="1.0.0"
BUILD_NUMBER="1"

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Flutter installation
check_flutter() {
    print_status "Checking Flutter installation..."
    
    if ! command_exists flutter; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    flutter --version
    print_success "Flutter is installed"
}

# Function to clean and get dependencies
setup_project() {
    print_status "Setting up project..."
    
    flutter clean
    flutter pub get
    
    print_success "Project setup complete"
}

# Function to run tests
run_tests() {
    print_status "Running tests..."
    
    if flutter test; then
        print_success "All tests passed"
    else
        print_error "Tests failed"
        exit 1
    fi
}

# Function to analyze code
analyze_code() {
    print_status "Analyzing code..."
    
    if flutter analyze; then
        print_success "Code analysis passed"
    else
        print_warning "Code analysis found issues"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Function to build iOS
build_ios() {
    print_status "Building iOS app..."
    
    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_warning "iOS builds require macOS"
        return 1
    fi
    
    # Check if Xcode is installed
    if ! command_exists xcodebuild; then
        print_error "Xcode is not installed"
        return 1
    fi
    
    flutter build ios --release --no-codesign
    
    print_success "iOS build complete"
    print_status "iOS app built at: build/ios/iphoneos/Runner.app"
}

# Function to build Android
build_android() {
    print_status "Building Android app..."
    
    flutter build appbundle --release
    
    print_success "Android build complete"
    print_status "Android app bundle built at: build/app/outputs/bundle/release/app-release.aab"
}

# Function to build web
build_web() {
    print_status "Building web app..."
    
    flutter build web --release
    
    print_success "Web build complete"
    print_status "Web app built at: build/web/"
}

# Function to build all platforms
build_all() {
    print_status "Building for all platforms..."
    
    setup_project
    run_tests
    analyze_code
    
    # Build for each platform
    build_ios || print_warning "iOS build failed"
    build_android || print_warning "Android build failed"
    build_web || print_warning "Web build failed"
    
    print_success "Build process complete"
}

# Function to create release archive
create_release() {
    print_status "Creating release archive..."
    
    RELEASE_DIR="releases/${APP_NAME}-v${VERSION}"
    mkdir -p "$RELEASE_DIR"
    
    # Copy builds
    if [ -d "build/ios/iphoneos" ]; then
        cp -r build/ios/iphoneos "$RELEASE_DIR/"
    fi
    
    if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
        cp build/app/outputs/bundle/release/app-release.aab "$RELEASE_DIR/"
    fi
    
    if [ -d "build/web" ]; then
        cp -r build/web "$RELEASE_DIR/"
    fi
    
    # Create release notes
    cat > "$RELEASE_DIR/RELEASE_NOTES.md" << EOF
# DuoTask v${VERSION} Release Notes

## What's New
- Initial release of DuoTask
- Beautiful bubble-based task interface
- Real-time task synchronization
- Voice-friendly design for on-the-go use
- Multi-partner support with frequent partners
- Smart task repetition and auto-deletion
- Relationship enhancement features
- Walking/driving mode for one-handed operation
- Comprehensive performance optimization

## Installation
- iOS: Install via App Store
- Android: Install via Google Play Store
- Web: Visit https://duotask.app

## System Requirements
- iOS 12.0 or later
- Android API level 21 or later
- Modern web browser (Chrome, Safari, Firefox, Edge)

## Known Issues
- None reported

## Support
For support, visit: https://duotask.app/support
EOF
    
    # Create zip archive
    cd releases
    zip -r "${APP_NAME}-v${VERSION}.zip" "${APP_NAME}-v${VERSION}"
    cd ..
    
    print_success "Release archive created: releases/${APP_NAME}-v${VERSION}.zip"
}

# Function to deploy to web hosting
deploy_web() {
    print_status "Deploying web app..."
    
    # Check if Firebase CLI is installed
    if command_exists firebase; then
        print_status "Deploying to Firebase Hosting..."
        firebase deploy --only hosting
        print_success "Web app deployed to Firebase"
    else
        print_warning "Firebase CLI not found. Please install it to deploy to Firebase Hosting."
        print_status "Web app files are ready at: build/web/"
    fi
}

# Function to show help
show_help() {
    echo "DuoTask Deployment Script"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  setup      Setup project (clean and get dependencies)"
    echo "  test       Run tests"
    echo "  analyze    Analyze code"
    echo "  ios        Build iOS app"
    echo "  android    Build Android app"
    echo "  web        Build web app"
    echo "  all        Build for all platforms"
    echo "  release    Create release archive"
    echo "  deploy     Deploy web app"
    echo "  help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 setup"
    echo "  $0 all"
    echo "  $0 release"
    echo "  $0 deploy"
}

# Function to check environment
check_environment() {
    print_status "Checking environment..."
    
    # Check Flutter
    check_flutter
    
    # Check if we're in the right directory
    if [ ! -f "pubspec.yaml" ]; then
        print_error "pubspec.yaml not found. Please run this script from the project root."
        exit 1
    fi
    
    # Check if pubspec.yaml contains the app name
    if ! grep -q "name: duotask" pubspec.yaml; then
        print_warning "pubspec.yaml doesn't seem to contain the correct app name"
    fi
    
    print_success "Environment check complete"
}

# Main script logic
main() {
    echo "🚀 DuoTask Deployment Script v${VERSION}"
    echo "=================================="
    
    # Check environment first
    check_environment
    
    # Parse command line arguments
    case "${1:-help}" in
        "setup")
            setup_project
            ;;
        "test")
            run_tests
            ;;
        "analyze")
            analyze_code
            ;;
        "ios")
            build_ios
            ;;
        "android")
            build_android
            ;;
        "web")
            build_web
            ;;
        "all")
            build_all
            ;;
        "release")
            build_all
            create_release
            ;;
        "deploy")
            build_web
            deploy_web
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "$@"
