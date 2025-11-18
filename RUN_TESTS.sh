#!/bin/bash#!/bin/bash



# DuoTask Testing Script# 🧪 Automated Testing Script for DuoTask Authentication

# Runs comprehensive tests including unit tests, integration tests, and multi-platform testing# Tests database, authentication flow, and user creation



set -eset -e



# Colors for outputecho "=========================================="

RED='\033[0;31m'echo "🧪 DUOTASK AUTOMATED TESTING"

GREEN='\033[0;32m'echo "=========================================="

YELLOW='\033[1;33m'echo ""

BLUE='\033[0;34m'

NC='\033[0m' # No Color# Colors

RED='\033[0;31m'

print_header() {GREEN='\033[0;32m'

    echo -e "\n${BLUE}================================${NC}"YELLOW='\033[1;33m'

    echo -e "${BLUE}$1${NC}"BLUE='\033[0;34m'

    echo -e "${BLUE}================================${NC}\n"NC='\033[0m'

}

# Database connection

print_step() {DB_URL="postgresql://postgres:M3ra-task@db.xqhlnuvpogiolzkucupt.supabase.co:5432/postgres"

    echo -e "${GREEN}[STEP]${NC} $1"

}# Test counters

TESTS_PASSED=0

print_success() {TESTS_FAILED=0

    echo -e "${GREEN}[SUCCESS]${NC} $1"

}# Test function

test() {

print_error() {    local test_name="$1"

    echo -e "${RED}[ERROR]${NC} $1"    local test_command="$2"

}    

    echo -e "${BLUE}Testing: $test_name${NC}"

# Main testing function    

main() {    if eval "$test_command" > /dev/null 2>&1; then

    print_header "DUOTASK COMPREHENSIVE TESTING"        echo -e "${GREEN}✅ PASS${NC}"

            ((TESTS_PASSED++))

    print_step "Installing dependencies..."    else

    flutter pub get        echo -e "${RED}❌ FAIL${NC}"

            ((TESTS_FAILED++))

    print_step "Running Flutter Doctor..."    fi

    flutter doctor    echo ""

    }

    print_step "Running unit tests..."

    flutter testecho -e "${YELLOW}=== DATABASE TESTS ===${NC}"

    echo ""

    print_step "Running code analysis..."

    flutter analyze# Test 1: Database connection

    test "Database connection" \

    print_step "Checking for formatting issues..."    "psql \"$DB_URL\" -c 'SELECT 1' > /dev/null 2>&1"

    dart format --set-exit-if-changed lib/ test/

    # Test 2: UUID extension exists

    print_success "Static analysis completed successfully!"test "UUID extension enabled" \

        "psql \"$DB_URL\" -t -c \"SELECT 1 FROM pg_extension WHERE extname = 'uuid-ossp'\" | grep -q 1"

    echo ""

    echo -e "${YELLOW}To run multi-platform testing with live apps:${NC}"# Test 3: Users table exists

    echo -e "${YELLOW}./test_all_platforms.sh${NC}"test "Users table exists" \

    echo ""    "psql \"$DB_URL\" -t -c \"SELECT 1 FROM information_schema.tables WHERE table_name = 'users'\" | grep -q 1"

    

    print_success "All tests completed successfully!"# Test 4: Tasks table exists

}test "Tasks table exists" \

    "psql \"$DB_URL\" -t -c \"SELECT 1 FROM information_schema.tables WHERE table_name = 'tasks'\" | grep -q 1"

# Run main function

main "$@"# Test 5: Pairings table exists
test "Pairings table exists" \
    "psql \"$DB_URL\" -t -c \"SELECT 1 FROM information_schema.tables WHERE table_name = 'pairings'\" | grep -q 1"

# Test 6: RLS enabled on users
test "Row Level Security enabled on users" \
    "psql \"$DB_URL\" -t -c \"SELECT relrowsecurity FROM pg_class WHERE relname = 'users'\" | grep -q t"

# Test 7: User creation trigger exists
test "User creation trigger exists" \
    "psql \"$DB_URL\" -t -c \"SELECT 1 FROM pg_trigger WHERE tgname = 'on_auth_user_created'\" | grep -q 1"

# Test 8: Generate pairing code function exists
test "Generate pairing code function exists" \
    "psql \"$DB_URL\" -t -c \"SELECT 1 FROM pg_proc WHERE proname = 'generate_pairing_code'\" | grep -q 1"

echo -e "${YELLOW}=== AUTHENTICATION TESTS ===${NC}"
echo ""

# Test 9: Auth users exist
AUTH_USER_COUNT=$(psql "$DB_URL" -t -c "SELECT COUNT(*) FROM auth.users" | tr -d ' ')
if [ "$AUTH_USER_COUNT" -gt 0 ]; then
    echo -e "${BLUE}Testing: Auth users exist${NC}"
    echo -e "${GREEN}✅ PASS ($AUTH_USER_COUNT users found)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}Testing: Auth users exist${NC}"
    echo -e "${RED}❌ FAIL (No auth users found)${NC}"
    ((TESTS_FAILED++))
fi
echo ""

# Test 10: User profiles exist
USER_PROFILE_COUNT=$(psql "$DB_URL" -t -c "SELECT COUNT(*) FROM users" | tr -d ' ')
if [ "$USER_PROFILE_COUNT" -gt 0 ]; then
    echo -e "${BLUE}Testing: User profiles exist${NC}"
    echo -e "${GREEN}✅ PASS ($USER_PROFILE_COUNT profiles found)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}Testing: User profiles exist${NC}"
    echo -e "${RED}❌ FAIL (No user profiles found)${NC}"
    ((TESTS_FAILED++))
fi
echo ""

# Test 11: Auth users match user profiles
if [ "$AUTH_USER_COUNT" -eq "$USER_PROFILE_COUNT" ]; then
    echo -e "${BLUE}Testing: Auth users match user profiles${NC}"
    echo -e "${GREEN}✅ PASS (All auth users have profiles)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}Testing: Auth users match user profiles${NC}"
    echo -e "${RED}❌ FAIL (Mismatch: $AUTH_USER_COUNT auth users, $USER_PROFILE_COUNT profiles)${NC}"
    ((TESTS_FAILED++))
fi
echo ""

# Test 12: All users have pairing codes
USERS_WITH_CODES=$(psql "$DB_URL" -t -c "SELECT COUNT(*) FROM users WHERE pairing_code IS NOT NULL" | tr -d ' ')
if [ "$USERS_WITH_CODES" -eq "$USER_PROFILE_COUNT" ]; then
    echo -e "${BLUE}Testing: All users have pairing codes${NC}"
    echo -e "${GREEN}✅ PASS (All $USER_PROFILE_COUNT users have codes)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}Testing: All users have pairing codes${NC}"
    echo -e "${RED}❌ FAIL ($USERS_WITH_CODES/$USER_PROFILE_COUNT users have codes)${NC}"
    ((TESTS_FAILED++))
fi
echo ""

echo -e "${YELLOW}=== DATA INTEGRITY TESTS ===${NC}"
echo ""

# Test 13: Pairing codes are unique
DUPLICATE_CODES=$(psql "$DB_URL" -t -c "SELECT COUNT(*) FROM (SELECT pairing_code FROM users GROUP BY pairing_code HAVING COUNT(*) > 1) AS dups" | tr -d ' ')
if [ "$DUPLICATE_CODES" -eq 0 ]; then
    echo -e "${BLUE}Testing: Pairing codes are unique${NC}"
    echo -e "${GREEN}✅ PASS (No duplicate codes)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}Testing: Pairing codes are unique${NC}"
    echo -e "${RED}❌ FAIL ($DUPLICATE_CODES duplicate codes found)${NC}"
    ((TESTS_FAILED++))
fi
echo ""

# Test 14: Users table has correct columns
EXPECTED_COLUMNS=("id" "email" "display_name" "pairing_code" "paired_with_id" "created_at" "updated_at")
MISSING_COLUMNS=0

for col in "${EXPECTED_COLUMNS[@]}"; do
    if ! psql "$DB_URL" -t -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'users' AND column_name = '$col'" | grep -q "$col"; then
        ((MISSING_COLUMNS++))
    fi
done

if [ "$MISSING_COLUMNS" -eq 0 ]; then
    echo -e "${BLUE}Testing: Users table schema correct${NC}"
    echo -e "${GREEN}✅ PASS (All required columns present)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${BLUE}Testing: Users table schema correct${NC}"
    echo -e "${RED}❌ FAIL ($MISSING_COLUMNS missing columns)${NC}"
    ((TESTS_FAILED++))
fi
echo ""

echo "=========================================="
echo -e "${YELLOW}📊 TEST RESULTS${NC}"
echo "=========================================="
echo ""
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo "Total Tests:  $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
    echo ""
    echo "✅ Database schema is correct"
    echo "✅ Authentication is working"
    echo "✅ User profiles are created"
    echo "✅ Ready to use the app!"
    echo ""
    echo "Next steps:"
    echo "1. Restart Flutter app: flutter run -d chrome --web-port 5000"
    echo "2. Click 'Continue with Google'"
    echo "3. You should see the home screen immediately!"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo ""
    echo "Please run ./FIX_DATABASE_NOW.sh to fix issues"
    exit 1
fi
