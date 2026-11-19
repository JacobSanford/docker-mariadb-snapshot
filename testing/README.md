# Testing

This directory contains automated tests for the docker-mariadb-snapshot image.

## Quick Start

Run all automated tests:

```bash
./run-tests.sh
```

The test runner is self-contained and requires no manual setup. For each database server image in `db-servers.txt` it builds the image, starts the server, runs all tests and cleans up.

To test against one server image only:

```bash
DB_SERVER_IMAGE=mariadb:11.4 ./run-tests.sh
```

## What Gets Tested

The test suite validates:

- All snapshot modes (single, multiple, auto-discovery)
- Structure-only table configurations (global and per-database)
- Combined snapshot feature
- File integrity and SQL validity
- Snapshot rotation

## Full Documentation

For comprehensive testing documentation, see **[running-tests.md](https://jacobsanford.github.io/docker-mariadb-snapshot/running-tests.md)**
