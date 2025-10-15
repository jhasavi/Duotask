#!/bin/bash

# DuoTask Development Scripts
# Usage: ./scripts/dev_scripts.sh [command]

set -e

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

# Function to check if Flutter is installed
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi
}

# Function to check if we're in the project root
check_project_root() {
    if [ ! -f "pubspec.yaml" ]; then
        print_error "Please run this script from the project root directory"
        exit 1
    fi
}

# Clean and get dependencies
clean_and_get() {
    print_status "Cleaning project and getting dependencies..."
    flutter clean
    flutter pub get
    print_success "Dependencies updated successfully"
}

# Run static analysis
analyze() {
    print_status "Running static analysis..."
    flutter analyze
    if [ $? -eq 0 ]; then
        print_success "Static analysis passed"
    else
        print_warning "Static analysis found issues"
    fi
}

# Run tests
test() {
    print_status "Running tests..."
    flutter test
    if [ $? -eq 0 ]; then
        print_success "All tests passed"
    else
        print_error "Some tests failed"
    fi
}

# Format code
format() {
    print_status "Formatting code..."
    dart format lib/ test/
    print_success "Code formatted"
}

# Build for all platforms
build_all() {
    print_status "Building for all platforms..."
    
    print_status "Building for Android..."
    flutter build apk --release
    
    print_status "Building for iOS..."
    flutter build ios --release
    
    print_status "Building for Web..."
    flutter build web --release
    
    print_status "Building for macOS..."
    flutter build macos --release
    
    print_success "All builds completed"
}

# Run on specific platform
run_platform() {
    local platform=$1
    case $platform in
        "android")
            print_status "Running on Android..."
            flutter run -d android
            ;;
        "ios")
            print_status "Running on iOS..."
            flutter run -d ios
            ;;
        "web")
            print_status "Running on Web..."
            flutter run -d chrome
            ;;
        "macos")
            print_status "Running on macOS..."
            flutter run -d macos
            ;;
        *)
            print_error "Unknown platform: $platform"
            print_status "Available platforms: android, ios, web, macos"
            exit 1
            ;;
    esac
}

# Generate code (drift, etc.)
generate() {
    print_status "Generating code..."
    flutter packages pub run build_runner build --delete-conflicting-outputs
    print_success "Code generation completed"
}

# Watch for changes and regenerate
watch_generate() {
    print_status "Watching for changes and regenerating code..."
    flutter packages pub run build_runner watch --delete-conflicting-outputs
}

# Check code coverage
coverage() {
    print_status "Running tests with coverage..."
    flutter test --coverage
    if [ -f "coverage/lcov.info" ]; then
        print_success "Coverage report generated at coverage/lcov.info"
    else
        print_warning "No coverage report generated"
    fi
}

# Lint and format check
lint_check() {
    print_status "Checking code style..."
    dart format --set-exit-if-changed lib/ test/
    if [ $? -eq 0 ]; then
        print_success "Code style is correct"
    else
        print_warning "Code style issues found"
    fi
}

# Full development workflow
dev_workflow() {
    print_status "Running full development workflow..."
    check_flutter
    check_project_root
    
    clean_and_get
    generate
    format
    lint_check
    analyze
    test
    
    print_success "Development workflow completed successfully"
}

# Show help
show_help() {
    echo "DuoTask Development Scripts"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  clean        - Clean project and get dependencies"
    echo "  analyze      - Run static analysis"
    echo "  test         - Run tests"
    echo "  format       - Format code"
    echo "  generate     - Generate code (drift, etc.)"
    echo "  watch        - Watch for changes and regenerate code"
    echo "  build        - Build for all platforms"
    echo "  run [platform] - Run on specific platform (android|ios|web|macos)"
    echo "  coverage     - Run tests with coverage"
    echo "  lint         - Check code style"
    echo "  workflow     - Run full development workflow"
    echo "  help         - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 clean"
    echo "  $0 run android"
    echo "  $0 workflow"
}

# Main script logic
main() {
    check_flutter
    check_project_root
    
    case $1 in
        "clean")
            clean_and_get
            ;;
        "analyze")
            analyze
            ;;
        "test")
            test
            ;;
        "format")
            format
            ;;
        "generate")
            generate
            ;;
        "watch")
            watch_generate
            ;;
        "build")
            build_all
            ;;
        "run")
            if [ -z "$2" ]; then
                print_error "Please specify a platform"
                print_status "Available platforms: android, ios, web, macos"
                exit 1
            fi
            run_platform $2
            ;;
        "coverage")
            coverage
            ;;
        "lint")
            lint_check
            ;;
        "workflow")
            dev_workflow
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
