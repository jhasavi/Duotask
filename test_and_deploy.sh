#!/bin/bash
# ============================================================================
# DuoTask: Test and Deploy Script
# ============================================================================

set -e  # Exit on error

echo "🚀 DuoTask: Pairing Improvements - Test & Deploy"
echo "=================================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. Check prerequisites
echo "📋 Step 1: Checking prerequisites..."
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter not found. Please install Flutter.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Flutter installed${NC}"

if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env file not found${NC}"
    exit 1
fi
echo -e "${GREEN}✅ .env file exists${NC}"

# 2. Get dependencies
echo ""
echo "📦 Step 2: Getting dependencies..."
flutter pub get
echo -e "${GREEN}✅ Dependencies installed${NC}"

# 3. Analyze code
echo ""
echo "🔍 Step 3: Analyzing code..."
flutter analyze --no-fatal-infos
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Code analysis passed${NC}"
else
    echo -e "${YELLOW}⚠️  Some warnings found (non-fatal)${NC}"
fi

# 4. Run tests
echo ""
echo "🧪 Step 4: Running tests..."
flutter test
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed${NC}"
else
    echo -e "${RED}❌ Some tests failed${NC}"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 5. Build web version
echo ""
echo "🌐 Step 5: Building web version..."
flutter build web --release
echo -e "${GREEN}✅ Web build complete${NC}"

# 6. Test checklist
echo ""
echo "✅ Step 6: Manual Testing Checklist"
echo "===================================="
echo ""
echo "Please test the following features:"
echo ""
echo "Before Pairing:"
echo "  [ ] Create task → Should be Personal automatically"
echo "  [ ] No Personal/Group toggle shown in dialog"
echo ""
echo "After Pairing:"
echo "  [ ] Create Personal task → Only you can see it"
echo "  [ ] Create Group task → Partner sees it immediately"
echo "  [ ] Filter by Personal → Only your tasks"
echo "  [ ] Filter by Group → Only shared tasks"
echo "  [ ] Both tap same task → No conflicts"
echo ""
echo "Colors & Sizes:"
echo "  [ ] Unclaimed by you: Yellow, large (120px)"
echo "  [ ] Unclaimed by partner: Orange, large (120px)"
echo "  [ ] Claimed by anyone: Blue, smaller (90px)"
echo "  [ ] Completed: Green, smallest (70px)"
echo ""
read -p "Have you tested all features? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️  Please test the features before deploying${NC}"
    exit 1
fi

# 7. Deploy to Vercel
echo ""
echo "🚀 Step 7: Deploying to Vercel..."
if command -v vercel &> /dev/null; then
    cd build/web
    vercel --prod
    cd ../..
    echo -e "${GREEN}✅ Deployed to Vercel${NC}"
else
    echo -e "${YELLOW}⚠️  Vercel CLI not found. Please install it:${NC}"
    echo "npm i -g vercel"
    echo ""
    echo "Or deploy manually:"
    echo "1. cd build/web"
    echo "2. vercel --prod"
fi

echo ""
echo "🎉 Deployment Complete!"
echo "======================"
echo ""
echo "📱 Your app is live at:"
echo "  - https://duotask-seven.vercel.app"
echo "  - https://duotask.namasteneedham.com (if DNS configured)"
echo ""
echo "📚 Documentation:"
echo "  - PAIRING_IMPROVEMENTS.md"
echo "  - QUICK_START_IMPROVEMENTS.md"
echo ""
