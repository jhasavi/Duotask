#!/bin/bash
# ============================================================================
# DuoTask: Database Migration Runner
# Opens Supabase SQL Editor and copies SQL to clipboard
# ============================================================================

echo "🗄️  DuoTask Database Migration"
echo "=============================="
echo ""

# Read Supabase URL from .env
SUPABASE_URL=$(grep SUPABASE_URL .env | cut -d '=' -f2)
SUPABASE_PROJECT_REF=$(echo $SUPABASE_URL | sed 's/https:\/\///' | cut -d '.' -f1)

echo "📋 Project: $SUPABASE_PROJECT_REF"
echo "🔗 URL: $SUPABASE_URL"
echo ""

# Copy SQL to clipboard if available
if command -v pbcopy &> /dev/null; then
    cat migrations/pairing_improvements.sql | pbcopy
    echo "✅ SQL copied to clipboard!"
else
    echo "ℹ️  Clipboard not available. You'll need to copy manually."
fi

echo ""
echo "🚀 Opening Supabase SQL Editor..."
echo ""
echo "1. The SQL Editor will open in your browser"
echo "2. Paste the SQL (already in clipboard if using macOS)"
echo "3. Click 'Run' to execute the migration"
echo "4. Look for success messages in the output"
echo ""

# Open Supabase SQL Editor
open "https://supabase.com/dashboard/project/$SUPABASE_PROJECT_REF/sql/new"

echo "⏳ Waiting for you to run the migration..."
echo ""
read -p "Press Enter once you've successfully run the migration..."

echo ""
echo "✅ Migration acknowledged!"
echo ""
echo "🧪 Now running tests..."
./test_and_deploy.sh
