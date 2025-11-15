# Testing

This directory contains automated tests for the docker-mariadb-snapshot container.

## Quick Start

Run all automated tests:

```bash
./run-tests.sh
```

The test runner is self-contained and requires no manual setup. It will build the image, start MySQL, run all tests, and clean up automatically.

## What Gets Tested

The test suite validates:

- All backup modes (single, multiple, auto-discovery)
- Structure-only table configurations (global and per-database)
- Combined backup feature
- File integrity and SQL validity
- Backup rotation

## Full Documentation

For comprehensive testing documentation, see **[../docs/running-tests.md](../docs/running-tests.md)**
