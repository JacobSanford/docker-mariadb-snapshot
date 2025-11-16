---
title: Running Tests
description: Developer guide for running automated and manual tests to validate docker-mariadb-snapshot functionality
audience: developers
doc_type: guide
tags: [testing, development, validation, automated-tests, debugging]
lastReviewed: 2025-11-15
version: 1.x
---

# Running Tests

Tests are provided for package-level testing of the docker-mariadb-snapshot image. They are not intended for end-users, but rather for developers and maintainers to validate functionality.

This page provides comprehensive guidance for testing the docker-mariadb-snapshot image, including automated test suites and manual testing procedures.

## Quick Start

The project includes an automated test suite in the `testing/` directory. To run all tests:

```bash
cd testing
./run-tests.sh
```

The test runner is completely self-contained and will:

1. Clean up old images and snapshots
2. Build the [Docker](https://www.docker.com){target="_blank"} image
3. Start [MySQL](https://www.mysql.com){target="_blank"} server
4. Wait for MySQL to be ready
5. Run all snapshot tests
6. Clean up containers

**No manual setup required!**

## What the Tests Cover

The automated test suite validates all snapshot modes and features:

### Snapshot Modes

1. **Single Database Snapshot** - Legacy mode backing up one database (app1)
2. **Multiple Databases Snapshot** - Explicit list of databases (app1, app2, app3)
3. **Auto-Discovery Snapshot** - Automatically discovers all non-system databases
4. **Per-Database Config** - Different structure-only table configurations per database
5. **Combined Snapshot** - Creates both individual files and ALL_DATABASES.gz

### Validation Checks

For each snapshot mode, tests verify:

- Snapshot files are created in correct locations
- Files are valid gzipped SQL
- Files contain expected database structures
- Structure-only tables have schema but no data (cache_*, sessions, temp_* tables)
- Combined snapshot contains all databases
- File sizes are reasonable (not empty or corrupt)

## Test Output

A successful test run looks like this:

```
==================================================
MySQL/MariaDB Snapshot Container - Test Suite
==================================================

Cleaning up old test snapshots...

Waiting for MySQL to be ready...
MySQL is ready

Running snapshot tests...

Test 1: Single database snapshot...  PASS
Test 2: Multiple databases snapshot (app1)...  PASS
Test 3: Multiple databases snapshot (app2)...  PASS
Test 4: Multiple databases snapshot (app3)...  PASS
Test 5: Auto-discovery snapshot (app1)...  PASS
Test 6: Auto-discovery snapshot (app2)...  PASS
Test 7: Auto-discovery snapshot (app3)...  PASS
Test 8: Per-DB config snapshot (app1)...  PASS
Test 9: Per-DB config snapshot (app2)...  PASS
Test 10: Combined snapshot created...  PASS
Test 11: Combined snapshot includes all DBs...  PASS
Test 12: Structure-only tables (cache_data)...  PASS
Test 13: Structure-only tables (cache_pages)...  PASS
Test 14: Per-DB structure-only (app1 cache)...  PASS
Test 15: Per-DB structure-only (app2 temp_files)...  PASS

==================================================
All tests passed! (15/15)
==================================================
```

## Manual Testing

If you need to test specific snapshot scenarios manually, use the following commands:

### Single Database Snapshot

```bash
cd testing
docker compose run --rm snapshot-single hourly
ls -la snapshots/single/hourly.0/mysql/
```

**Expected output:** `app1.gz` file with cache and session tables structure-only

### Multiple Databases

```bash
docker compose run --rm snapshot-multiple daily
ls -la snapshots/multiple/daily.0/mysql/
```

**Expected output:** `app1.gz`, `app2.gz`, `app3.gz` files

### Auto-Discovery

```bash
docker compose run --rm snapshot-all weekly
ls -la snapshots/all/weekly.0/mysql/
```

**Expected output:** One `.gz` file per discovered database (app1, app2, app3)

### Per-Database Configuration

```bash
docker compose run --rm snapshot-per-db-config hourly
ls -la snapshots/per-db/hourly.0/mysql/
```

**Expected output:**
- `app1.gz` with cache, sessions, and watchdog tables structure-only
- `app2.gz` with temp_files and cache tables structure-only

### Combined Snapshot

```bash
docker compose run --rm snapshot-combined daily
ls -la snapshots/combined/daily.0/mysql/
```

**Expected output:**
- Individual database files: `app1.gz`, `app2.gz`, `app3.gz`
- Combined file: `ALL_DATABASES.gz`

## Inspecting Snapshot Files

### View Snapshot Contents

To decompress and view a snapshot without restoring:

```bash
gunzip -c snapshots/single/hourly.0/mysql/app1.gz | less
```

### Check for Structure-Only Tables

Verify that structure-only tables have no INSERT statements:

```bash
gunzip -c snapshots/single/hourly.0/mysql/app1.gz | grep -i "INSERT INTO.*cache_data"
```

**Expected:** No output (table data was excluded)

Check that structure exists:

```bash
gunzip -c snapshots/single/hourly.0/mysql/app1.gz | grep -i "CREATE TABLE.*cache_data"
```

**Expected:** CREATE TABLE statement found

### Restore to MySQL for Testing

Restore a snapshot to your test MySQL server:

```bash
gunzip -c snapshots/single/hourly.0/mysql/app1.gz | \
  docker compose exec -T mysql mysql -u root -prootpassword app1
```

Or restore to a different database name:

```bash
# Create new database
docker compose exec mysql mysql -u root -prootpassword -e "CREATE DATABASE app1_restored"

# Restore snapshot
gunzip -c snapshots/single/hourly.0/mysql/app1.gz | \
  docker compose exec -T mysql mysql -u root -prootpassword app1_restored
```

## Test Database Structure

The test MySQL server is initialized with three databases for comprehensive testing:

### app1 Database

Tables:
- `cache_data` - Structure-only (matches `cache_*` pattern)
- `cache_pages` - Structure-only (matches `cache_*` pattern)
- `sessions` - Structure-only
- `watchdog` - Structure-only in per-DB config tests
- `users` - Regular table with full data snapshot

### app2 Database

Tables:
- `temp_files` - Structure-only in per-DB config (matches `temp_*` pattern)
- `cache` - Structure-only in per-DB config
- `posts` - Regular table with full data snapshot

### app3 Database

Tables:
- `products` - Regular table with full data snapshot
- `orders` - Regular table with full data snapshot

This structure ensures tests cover:
- Pattern matching with wildcards (`cache_*`, `temp_*`)
- Exact table name matching (`sessions`, `watchdog`, `cache`)
- Per-database configuration variations
- Databases without structure-only tables

## Cleanup

### Clean Up Test Data

To remove all test containers and snapshots:

```bash
cd testing
docker compose down -v
rm -rf snapshots
```

### Clean Up Individual Snapshot Directories

```bash
rm -rf snapshots/single
rm -rf snapshots/multiple
rm -rf snapshots/all
rm -rf snapshots/per-db
rm -rf snapshots/combined
```

## Troubleshooting

### Tests Fail with "MySQL is not ready"

**Cause:** MySQL container is still initializing.

**Solution:** Wait a few seconds for MySQL to finish starting, then run tests again:

```bash
# Check MySQL status
docker compose ps mysql

# Wait for healthy status
docker compose up -d mysql
sleep 10

# Run tests
./run-tests.sh
```

### Permission Errors When Running Tests

**Cause:** `run-tests.sh` script is not executable.

**Solution:** Make the script executable:

```bash
chmod +x run-tests.sh
```

### Snapshot Files Not Found

**Cause:** MySQL server not running before snapshot execution.

**Solution:** Start MySQL first:

```bash
docker compose up -d mysql

# Wait for healthy status
docker compose ps mysql

# Run snapshot
docker compose run --rm snapshot-single hourly
```

### Structure-Only Table Validation Fails

**Cause:** Test data was not properly initialized.

**Solution:** Recreate the MySQL container with fresh data:

```bash
docker compose down -v
docker compose up -d mysql

# Wait for initialization
sleep 10

# Run tests
./run-tests.sh
```

### Docker Compose Command Not Found

**Cause:** [Docker Compose](https://docs.docker.com/compose/){target="_blank"} not installed or using old syntax.

**Solution:** Update Docker Compose:

```bash
# Modern Docker with integrated compose
docker compose version

# If using old standalone compose
docker-compose version
```

Replace `docker compose` with `docker-compose` if using the standalone version.

## Continuous Integration

The project uses GitHub Actions for automated testing. See `.github/workflows/ci.yml` for the CI configuration.

Tests run automatically on:
- Push to main branches
- Pull requests
- Manual workflow dispatch

## Writing Custom Tests

To add your own test scenarios, create a new service in `testing/docker-compose.yml`:

```yaml
services:
  snapshot-custom:
    build:
      context: ..
      dockerfile: Dockerfile
    environment:
      # Your custom configuration
      DB_HOSTNAME: mysql
      DB_DATABASE: mydb
      # Add other settings
    volumes:
      - ./snapshots/custom:/data
    depends_on:
      mysql:
        condition: service_healthy
```

Run your custom test:

```bash
docker compose run --rm snapshot-custom hourly
ls -la snapshots/custom/hourly.0/mysql/
```

## Next Steps

- **[Configuration Reference](configuration.md)** - Learn about all environment variables
- **[Docker Compose Examples](docker-compose.md)** - See production-ready configurations
- **[Quick Start Guide](quickstart.md)** - Basic usage examples
