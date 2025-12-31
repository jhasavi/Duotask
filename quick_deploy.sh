#!/bin/bash
# ============================================================================
# Quick Migration & Test - All-in-One Script
# ============================================================================

set -e

echo "🚀 DuoTask: Quick Migration, Test & Deploy"
echo "==========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Step 1: Copy SQL to clipboard
echo "📋 Step 1: Copying SQL to clipboard..."
cat migrations/pairing_improvements.sql | pbcopy
echo -e "${GREEN}✅ SQL copied!${NC}"
echo ""

# Step 2: Open Supabase
echo "🗄️  Step 2: Opening Supabase SQL Editor..."
echo "➡️  Paste and run the SQL in the editor"
open "https://supabase.com/dashboard/project/xqhlnuvpogiolzkucupt/sql/new"
echo ""
echo "⏳ Please:"
echo "   1. Paste the SQL (Cmd+V)"
echo "   2. Click 'RUN' button"
echo "   3. Wait for success messages"
echo ""
read -p "Press Enter once migration is complete..."
echo -e "${GREEN}✅ Migration complete!${NC}"
echo ""

# Step 3: Get dependencies
echo "📦 Step 3: Getting dependencies..."
flutter pub get
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

# Step 4: Quick compile check
echo "🔍 Step 4: Checking code..."
flutter analyze --no-fatal-infos || echo -e "${YELLOW}⚠️  Some warnings (OK to continue)${NC}"
echo ""

# Step 5: Build for web
echo "🌐 Step 5: Building web version..."
flutter build web --release
echo -e "${GREEN}✅ Web build complete${NC}"
echo ""

# Step 6: Test locally
echo "🧪 Step 6: Testing locally..."
echo ""
echo "Starting web server on http://localhost:8080"
echo "Test the following features:"
echo ""
echo -e "${BLUE}Before Pairing:${NC}"
echo "  • Create task (should be Personal)"
echo "  • No toggle shown"
echo ""
echo -e "${BLUE}After Pairing:${NC}"
echo "  • Click 'New Task' FAB"
echo "  • See Personal/Group toggle"
echo "  • Create both types"
echo "  • Use filter chips"
echo "  • Test task cycling (tap bubbles)"
echo ""
echo "Press Ctrl+C when done testing"
echo ""

cd build/web
python3 -m http.server 8080 2>/dev/null || python -m SimpleHTTPServer 8080

