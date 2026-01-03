#!/bin/bash

# DuoTask Quick Test Script
# This script tests basic functionality after deployment

set -e

echo "🧪 DuoTask Quick Test Suite"
echo "=============================="
echo ""

# Configuration
APP_URL="https://duotask-seven.vercel.app"
API_URL="https://xqhlnuvpogiolzkucupt.supabase.co"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhxaGxudXZwb2dpb2x6a3VjdXB0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE5MTA1NzgsImV4cCI6MjA2NzQ4NjU3OH0.9lw-X6mjpPFfTqpiiTEOpzWZEfqnPkW0ADA6XfbLsNw"

# Test 1: Web App Availability
echo "📱 Test 1: Web App Availability"
echo "   Testing: $APP_URL"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$APP_URL")
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ PASSED: Web app is online (HTTP $HTTP_CODE)"
else
    echo "   ❌ FAILED: Web app returned HTTP $HTTP_CODE"
    exit 1
fi
echo ""

# Test 2: Supabase API
echo "🗄️  Test 2: Supabase API Connection"
echo "   Testing: $API_URL/rest/v1/"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $ANON_KEY" \
    "$API_URL/rest/v1/")
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ PASSED: Supabase API is accessible (HTTP $HTTP_CODE)"
else
    echo "   ❌ FAILED: Supabase API returned HTTP $HTTP_CODE"
    exit 1
fi
echo ""

# Test 3: Email Function
echo "📧 Test 3: Email Edge Function"
echo "   Testing: $API_URL/functions/v1/daily-email-digest"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $ANON_KEY" \
    -H "Content-Type: application/json" \
    "$API_URL/functions/v1/daily-email-digest")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ PASSED: Email function responded (HTTP $HTTP_CODE)"
    echo "   Response: $BODY"
else
    echo "   ❌ FAILED: Email function returned HTTP $HTTP_CODE"
    echo "   Response: $BODY"
    exit 1
fi
echo ""

# Test 4: Database Tables (check if migrations ran)
echo "🗃️  Test 4: Database Tables"
echo "   Checking: email_preferences table"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $ANON_KEY" \
    "$API_URL/rest/v1/email_preferences?select=count")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ PASSED: email_preferences table exists"
else
    echo "   ⚠️  WARNING: email_preferences table may not exist (HTTP $HTTP_CODE)"
fi
echo ""

echo "   Checking: nudges table"
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -H "apikey: $ANON_KEY" \
    -H "Authorization: Bearer $ANON_KEY" \
    "$API_URL/rest/v1/nudges?select=count")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
if [ "$HTTP_CODE" = "200" ]; then
    echo "   ✅ PASSED: nudges table exists"
else
    echo "   ⚠️  WARNING: nudges table may not exist (HTTP $HTTP_CODE)"
fi
echo ""

# Summary
echo "=============================="
echo "✨ Test Suite Complete!"
echo ""
echo "Next Steps:"
echo "1. Run SQL scripts in Supabase:"
echo "   - migrations/init_email_preferences.sql"
echo "   - migrations/setup_email_cron.sql"
echo ""
echo "2. Manual testing:"
echo "   - Login and verify pairing"
echo "   - Test Personal/Paired tabs"
echo "   - Test ownership lock"
echo "   - Check daily banner"
echo ""
echo "3. Check email delivery:"
echo "   - Wait for 8 AM UTC or trigger manually"
echo "   - Verify emails in inbox"
echo ""
echo "📖 Full testing guide: TESTING_GUIDE.md"
echo "🚀 Deployment docs: DEPLOYMENT_COMPLETE.md"
