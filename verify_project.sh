#!/bin/bash

# DuoTask Project Verification Script
# This script validates that the project is ready to run

echo "🔍 DuoTask Project Verification"
echo "================================"
echo ""

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found"
    exit 1
else
    echo "✅ Flutter installed"
fi

# Check .env file
if [ ! -f ".env" ]; then
    echo "❌ .env file not found"
    echo "   Run: cp .env.example .env and configure it"
    exit 1
else
    echo "✅ .env file exists"
fi

# Check if dependencies are installed
if [ ! -d ".dart_tool" ]; then
    echo "⚠️  Dependencies not installed"
    echo "   Running: flutter pub get"
    flutter pub get
fi

echo "✅ Dependencies installed"
echo ""

# Run analyzer
echo "📝 Running code analysis..."
flutter analyze --no-pub > /tmp/duotask_analyze.txt 2>&1

ERRORS=$(grep -c "error •" /tmp/duotask_analyze.txt || true)
WARNINGS=$(grep -c "warning •" /tmp/duotask_analyze.txt || true)

if [ "$ERRORS" -gt 0 ]; then
    echo "❌ Found $ERRORS error(s)"
    grep "error •" /tmp/duotask_analyze.txt | head -5
    exit 1
else
    echo "✅ No errors found"
fi

if [ "$WARNINGS" -gt 0 ]; then
    echo "⚠️  Found $WARNINGS warning(s) (non-critical)"
else
    echo "✅ No warnings found"
fi

echo ""

# Check project structure
echo "📁 Verifying project structure..."
REQUIRED_DIRS=(
    "lib/config"
    "lib/models"
    "lib/screens"
    "lib/services"
    "lib/widgets"
    "supabase"
    "test"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "❌ Missing directory: $dir"
        exit 1
    fi
done
echo "✅ All required directories present"

# Count Dart files
DART_FILES=$(find lib -name "*.dart" | wc -l | xargs)
echo "✅ Found $DART_FILES Dart files"

echo ""
echo "🎉 Project Verification Complete!"
echo ""
echo "Project Status:"
echo "  • Flutter: ✅ Ready"
echo "  • Dependencies: ✅ Installed"
echo "  • Code Analysis: ✅ Passed"
echo "  • Structure: ✅ Valid"
echo "  • Files: $DART_FILES Dart files"
echo ""
echo "Next Steps:"
echo "  1. Configure .env with your Supabase and Google OAuth credentials"
echo "  2. Run: ./quick_start.sh"
echo "  3. Or run manually: flutter run -d chrome --web-port 5000"
echo ""
