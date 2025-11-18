#!/bin/bash

# DuoTask Quick Start Script
# This script gets you up and running with DuoTask quickly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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
    echo -e "${PURPLE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Flutter is installed
check_flutter() {
    if ! command -v flutter >/dev/null 2>&1; then
        print_error "Flutter is not installed or not in PATH"
        echo "Please install Flutter from: https://flutter.dev/docs/get-started/install"
        exit 1
    fi
    print_success "Flutter is available"
}

# Main function
main() {
    print_header "DUOTASK QUICK START"
    
    print_info "Welcome to DuoTask! This script will get you running quickly."
    echo ""
    
    check_flutter
    
    print_step "Installing dependencies..."
    flutter pub get
    
    print_step "Running quick validation..."
    flutter doctor --version
    
    print_success "Setup complete!"
    
    print_header "WHAT'S NEXT?"
    
    echo -e "${PURPLE}Choose your testing approach:${NC}"
    echo ""
    echo -e "${YELLOW}1. Multi-platform testing (Recommended):${NC}"
    echo "   ./test_all_platforms.sh"
    echo "   - Launches Web, iOS, and Android simultaneously"
    echo "   - Provides guided testing instructions"
    echo "   - Tests pairing and real-time sync"
    echo ""
    echo -e "${YELLOW}2. Single platform testing:${NC}"
    echo "   flutter run -d chrome --web-port 5000    # Web"
    echo "   flutter run -d ios                       # iOS"
    echo "   flutter run -d android                   # Android"
    echo ""
    echo -e "${YELLOW}3. Run automated tests:${NC}"
    echo "   ./RUN_TESTS.sh"
    echo "   - Unit tests, code analysis, formatting checks"
    echo ""
    
    print_header "QUICK TESTING TIPS"
    echo "🔐 Authentication: Use Google Sign-In or create account with email"
    echo "🤝 Pairing: Generate code on device 1, enter on device 2"
    echo "📋 Tasks: Type naturally like 'Grocery shopping @6pm'"
    echo "⚡ Sync: Changes appear instantly across paired devices"
    echo "🎨 Visual: Orange=unclaimed, Blue=claimed, Green=completed"
    echo ""
    
    print_success "Ready to start! Run your chosen command above."
}

# Run main function
main "$@"