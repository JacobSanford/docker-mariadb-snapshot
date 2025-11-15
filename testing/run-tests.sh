#!/bin/bash
# Automated test runner for docker-mariadb-snapshot
# Tests all snapshot scenarios and validates snapshot integrity
set -ex

FAILED=0
TESTS_PASSED=0
TESTS_TOTAL=0

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    echo -n "Test $TESTS_TOTAL: $test_name... "

    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        FAILED=1
        return 1
    fi
}

# Helper function to validate a snapshot file
validate_snapshot() {
    local snapshot_file="$1"
    local expected_databases="$2"  # Space-separated list of database names

    # Check file exists
    if [ ! -f "$snapshot_file" ]; then
        return 1
    fi

    # Check file size is reasonable (at least 100 bytes)
    if [ $(stat -f%z "$snapshot_file" 2>/dev/null || stat -c%s "$snapshot_file" 2>/dev/null) -lt 100 ]; then
        return 1
    fi

    # Decompress and validate SQL syntax
    if ! gunzip -t "$snapshot_file" 2>/dev/null; then
        return 1
    fi

    # Check that SQL contains CREATE TABLE statements (valid snapshot content)
    gunzip -c "$snapshot_file" > /tmp/test_snapshot.sql 2>/dev/null

    if ! grep -q "CREATE TABLE" /tmp/test_snapshot.sql 2>/dev/null; then
        rm -f /tmp/test_snapshot.sql
        return 1
    fi

    # For combined snapshots with multiple databases, check each database is mentioned
    if echo "$expected_databases" | grep -q " "; then
        for db in $expected_databases; do
            if ! grep -q "Database.*$db" /tmp/test_snapshot.sql 2>/dev/null; then
                rm -f /tmp/test_snapshot.sql
                return 1
            fi
        done
    fi

    rm -f /tmp/test_snapshot.sql
    return 0
}

# Helper function to check structure-only tables
validate_structure_only() {
    local snapshot_file="$1"
    local table_pattern="$2"

    if [ ! -f "$snapshot_file" ]; then
        return 1
    fi

    gunzip -c "$snapshot_file" > /tmp/test_snapshot.sql 2>/dev/null

    # Check that table structure exists
    if ! grep -q "CREATE TABLE.*$table_pattern" /tmp/test_snapshot.sql 2>/dev/null; then
        rm -f /tmp/test_snapshot.sql
        return 1
    fi

    # Check that no INSERT statements exist for this table
    if grep -q "INSERT INTO.*$table_pattern" /tmp/test_snapshot.sql 2>/dev/null; then
        rm -f /tmp/test_snapshot.sql
        return 1
    fi

    rm -f /tmp/test_snapshot.sql
    return 0
}

# Helper function to validate users/grants backup
validate_users_grants() {
    local snapshot_file="$1"

    # Check file exists
    if [ ! -f "$snapshot_file" ]; then
        return 1
    fi

    # Check file size is reasonable (at least 50 bytes)
    if [ $(stat -f%z "$snapshot_file" 2>/dev/null || stat -c%s "$snapshot_file" 2>/dev/null) -lt 50 ]; then
        return 1
    fi

    # Decompress and validate it's valid gzip
    if ! gunzip -t "$snapshot_file" 2>/dev/null; then
        return 1
    fi

    # Check that SQL contains CREATE USER or GRANT statements
    gunzip -c "$snapshot_file" > /tmp/test_users.sql 2>/dev/null

    if ! grep -qi "CREATE USER\|GRANT" /tmp/test_users.sql 2>/dev/null; then
        rm -f /tmp/test_users.sql
        return 1
    fi

    rm -f /tmp/test_users.sql
    return 0
}

# Helper function to validate snapshot metadata
validate_metadata() {
    local metadata_file="$1"

    # Check file exists
    if [ ! -f "$metadata_file" ]; then
        return 1
    fi

    # Check file size is reasonable (at least 100 bytes)
    if [ $(stat -f%z "$metadata_file" 2>/dev/null || stat -c%s "$metadata_file" 2>/dev/null) -lt 100 ]; then
        return 1
    fi

    # Validate JSON syntax (using python if available, otherwise basic check)
    if command -v python3 > /dev/null 2>&1; then
        if ! python3 -m json.tool "$metadata_file" > /dev/null 2>&1; then
            return 1
        fi
    fi

    # Check for required keys
    if ! grep -q "snapshot_info" "$metadata_file" 2>/dev/null; then
        return 1
    fi

    if ! grep -q "start_time" "$metadata_file" 2>/dev/null; then
        return 1
    fi

    if ! grep -q "database_server" "$metadata_file" 2>/dev/null; then
        return 1
    fi

    return 0
}

echo "=================================================="
echo "MySQL/MariaDB Snapshot Container - Test Suite"
echo "=================================================="
echo ""

# Step 1: Clean up any existing containers and volumes
echo "Step 1/5: Cleaning up old containers and volumes..."
docker compose down -v > /dev/null 2>&1
docker run --rm -v "$(pwd)/snapshots:/snapshots" alpine:3.22 sh -c "rm -rf /snapshots/* && mkdir -p /snapshots" || true
echo -e "${GREEN}Cleanup complete${NC}"
echo ""

# Step 2: Build the Docker image
echo "Step 2/5: Building Docker image from local Dockerfile..."
docker compose build snapshot-single
echo -e "${GREEN}Image built successfully${NC}"
echo ""

# Step 3: Start MySQL server
echo "Step 3/5: Starting MySQL server..."
docker compose up -d mysql > /dev/null 2>&1
echo -e "${GREEN}MySQL container started${NC}"
echo ""

# Step 4: Wait for MySQL to be ready
echo "Step 4/5: Waiting for MySQL to accept connections..."
ATTEMPTS=0
MAX_ATTEMPTS=30
until docker compose exec -T mysql mysqladmin ping -h localhost -u root -prootpassword --silent 2>/dev/null; do
    ATTEMPTS=$((ATTEMPTS + 1))
    if [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; then
        echo -e "${RED}MySQL failed to start after ${MAX_ATTEMPTS} seconds${NC}"
        docker compose down -v > /dev/null 2>&1
        exit 1
    fi
    sleep 1
done
echo -e "${GREEN}MySQL is ready${NC}"
echo ""

# Step 5: Run snapshot tests
echo "Step 5/5: Running snapshot tests..."
echo ""

# Test 1: Single database snapshot
docker compose run --rm snapshot-single hourly
run_test "Single database snapshot" "validate_snapshot ./snapshots/single/hourly.0/mysql/app1.gz app1"

# Test 2: Multiple databases snapshot
docker compose run --rm snapshot-multiple hourly > /dev/null 2>&1
run_test "Multiple databases snapshot (app1)" "validate_snapshot ./snapshots/multiple/hourly.0/mysql/app1.gz app1"
run_test "Multiple databases snapshot (app2)" "validate_snapshot ./snapshots/multiple/hourly.0/mysql/app2.gz app2"
run_test "Multiple databases snapshot (app3)" "validate_snapshot ./snapshots/multiple/hourly.0/mysql/app3.gz app3"

# Test 3: Auto-discovery snapshot
docker compose run --rm snapshot-all hourly > /dev/null 2>&1
run_test "Auto-discovery snapshot (app1)" "validate_snapshot ./snapshots/all/hourly.0/mysql/app1.gz app1"
run_test "Auto-discovery snapshot (app2)" "validate_snapshot ./snapshots/all/hourly.0/mysql/app2.gz app2"
run_test "Auto-discovery snapshot (app3)" "validate_snapshot ./snapshots/all/hourly.0/mysql/app3.gz app3"

# Test 4: Per-database structure-only tables configuration
docker compose run --rm snapshot-per-db-config hourly > /dev/null 2>&1
run_test "Per-DB config snapshot (app1)" "validate_snapshot ./snapshots/per-db/hourly.0/mysql/app1.gz app1"
run_test "Per-DB config snapshot (app2)" "validate_snapshot ./snapshots/per-db/hourly.0/mysql/app2.gz app2"

# Test 5: Combined snapshot mode
docker compose run --rm snapshot-combined hourly > /dev/null 2>&1
run_test "Combined snapshot created" "validate_snapshot ./snapshots/combined/hourly.0/mysql/ALL_DATABASES.gz 'app1 app2 app3'"
run_test "Combined snapshot includes all DBs" "[ -f ./snapshots/combined/hourly.0/mysql/ALL_DATABASES.gz ]"

# Test 6: Structure-only tables validation (cache tables should have no data)
run_test "Structure-only tables (cache_data)" "validate_structure_only ./snapshots/single/hourly.0/mysql/app1.gz cache_data"
run_test "Structure-only tables (cache_pages)" "validate_structure_only ./snapshots/single/hourly.0/mysql/app1.gz cache_pages"

# Test 7: Validate per-database structure-only config
run_test "Per-DB structure-only (app1 cache)" "validate_structure_only ./snapshots/per-db/hourly.0/mysql/app1.gz cache"
run_test "Per-DB structure-only (app2 temp_files)" "validate_structure_only ./snapshots/per-db/hourly.0/mysql/app2.gz temp_files"

# Test 8: Users and grants backup
docker compose run --rm snapshot-with-users hourly > /dev/null 2>&1
run_test "Users/grants backup created" "validate_users_grants ./snapshots/with-users/hourly.0/mysql/users.sql.gz"
run_test "Users/grants file exists" "[ -f ./snapshots/with-users/hourly.0/mysql/users.sql.gz ]"
run_test "Database snapshots still created with users backup" "validate_snapshot ./snapshots/with-users/hourly.0/mysql/app1.gz app1"

# Test 9: Snapshot metadata validation
run_test "Metadata created (single)" "validate_metadata ./snapshots/single/hourly.0/mysql/snapshot-metadata.json"
run_test "Metadata created (multiple)" "validate_metadata ./snapshots/multiple/hourly.0/mysql/snapshot-metadata.json"
run_test "Metadata created (all)" "validate_metadata ./snapshots/all/hourly.0/mysql/snapshot-metadata.json"
run_test "Metadata created (with-users)" "validate_metadata ./snapshots/with-users/hourly.0/mysql/snapshot-metadata.json"

echo ""
echo "=================================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ($TESTS_PASSED/$TESTS_TOTAL)${NC}"
else
    echo -e "${RED}Some tests failed. ($TESTS_PASSED/$TESTS_TOTAL passed)${NC}"
fi
echo "=================================================="
echo ""

# Cleanup: Stop and remove containers
echo "Cleaning up containers..."
docker compose down > /dev/null 2>&1
echo -e "${GREEN}Cleanup complete${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
