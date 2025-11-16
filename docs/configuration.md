---
title: Configuration Reference
description: Complete reference for all environment variables and configuration options for docker-mariadb-snapshot
audience: users
doc_type: reference
tags: [configuration, environment-variables, settings, retention, database]
lastReviewed: 2025-11-15
version: 1.x
---

# Snapshot Configuration
This page provides a complete reference for all configuration options. All configuration options are set via environment variables within the running container.

## Rsnapshot Retention Settings
Control how many snapshots are retained by rsnapshot (follows [rsnapshot retention models](https://wiki.archlinux.org/title/Rsnapshot){target="_blank"}):

| Variable | Description | Default |
|----------|-------------|---------|
| `RSNAPSHOT_RETAIN_HOURLY` | Number of hourly snapshots to retain | `8` |
| `RSNAPSHOT_RETAIN_DAILY` | Number of daily snapshots to retain | `7` |
| `RSNAPSHOT_RETAIN_WEEKLY` | Number of weekly snapshots to retain | `4` |
| `RSNAPSHOT_RETAIN_MONTHLY` | Number of monthly snapshots to retain | `6` |

## General Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `GZIP_COMPRESSION_LEVEL` | Level of [gzip compression](https://en.wikipedia.org/wiki/Gzip){target="_blank"} (1-9, where 9 is maximum compression) | `6` |
| `DB_DUMP_LOCATION` | Directory where snapshot files will be stored | `/data` |
| `DB_DEFAULT_CHARSET` | Character set used for [mariadb-dump](https://mariadb.com/kb/en/mariadb-dump/){target="_blank"} operations | `utf8mb4` |

**Tip:** Higher compression levels reduce file size but increase CPU usage and snapshot time.

## MySQL Connection Parameters

Configure how docker-mariadb-snapshot connects to your MariaDB/MySQL server:

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_HOSTNAME` | Hostname or IP address of the MySQL server | `localhost` |
| `DB_PORT` | Port number of the MySQL server | `3306` |
| `DB_USER_NAME` | Username for connecting to MySQL | `root` |
| `DB_USER_PASSWORD` | Password for connecting to MySQL | `changeme` |

**Security Note:** Always use a dedicated snapshot user with minimal required privileges (`SELECT`, `LOCK TABLES`, `SHOW VIEW`, `EVENT`, `TRIGGER`).

## Database Selection Modes

docker-mariadb-snapshot supports three ways to select databases for snapshot. If multiple modes are configured, they are evaluated in priority order.

### Mode 1: Explicit List

Snapshot a specific list of databases. Each database is backed up to a separate `.gz` file.

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_DATABASES` | Comma-separated list of databases to snapshot | `db1,db2,db3` |

### Mode 2: Auto-Discovery

Automatically discover and snapshot all databases on the server, excluding system databases.

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_SNAPSHOT_ALL_DATABASES` | Set to `true` or `1` to enable auto-discovery | (disabled) |
| `DB_EXCLUDE_DATABASES` | Comma-separated list of databases to exclude | `information_schema,performance_schema,mysql,sys` |
| `DB_SNAPSHOT_COMBINED` | Set to `true` or `1` to create additional combined snapshot file | (disabled) |

### Mode 3: Single Database - Legacy

Snapshot a single specific database. This is the original behavior maintained for backward compatibility. Do not use this mode, as it may be removed in future releases.

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_DATABASE` | Single database to snapshot | `myapp` |


## Structure-Only Tables
Often, certain tables (like cache or session tables) do not need their data backed up, only their structure. This feature allows you to specify tables whose data should be excluded from the snapshot while preserving their schema.

### Global Configuration
To exclude structure-only tables across all snapshotted databases:

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_STRUCT_TABLES` | Comma-separated list of table patterns (supports wildcards) | `cache_*,sessions` |

This excludes data from any tables matching:
- `cache_*` (e.g., `cache_data`, `cache_pages`)
- `sessions`
- `temp_*` (e.g., `temp_files`, `temp_uploads`)

**Pattern Matching:**
- `*` matches any characters
- Patterns are matched against actual table names using `SHOW TABLES LIKE`
- If a pattern matches no tables, it's silently ignored

### Per-Database Configuration
You can also configure structure-only tables per database using the format:

```
DB_STRUCT_TABLES_<NORMALIZED_DB_NAME>
```

Where `<NORMALIZED_DB_NAME>` is the database name:
- Converted to uppercase
- Hyphens (`-`) replaced with underscores (`_`)
- Periods (`.`) replaced with underscores (`_`)

**Examples:**

| Database Name | Environment Variable | Example Value |
|---------------|---------------------|---------------|
| `myapp` | `DB_STRUCT_TABLES_MYAPP` | `cache_%,sessions` |
| `my_app` | `DB_STRUCT_TABLES_MY_APP` | `cache_%,sessions` |
| `my-app` | `DB_STRUCT_TABLES_MY_APP` | `cache_%,sessions` |
| `my.app` | `DB_STRUCT_TABLES_MY_APP` | `cache_%,sessions` |

## Users and Grants Snapshot

In addition to backing up database contents, you can also snapshot MariaDB/MySQL user accounts and their grants. This creates a separate snapshot file containing user definitions and privileges.

| Variable | Description | Default |
|----------|-------------|---------|
| `DB_SNAPSHOT_USERS_GRANTS` | Set to `true` or `1` to snapshot users and grants | (disabled) |

When enabled, docker-mariadb-snapshot will create an additional file `users.sql.gz` containing:
- User account definitions (`CREATE USER` statements)
- Grant permissions (`GRANT` statements)
- Password hashes and authentication plugins

**Important Notes:**
- The database user must have privileges to read the `mysql` system database
- The snapshot user typically needs `SELECT` privilege on `mysql.*` to dump users
- User snapshots are created once per snapshot invocation (not per database)
- This feature can be used with any database selection mode (single, explicit list, or auto-discovery)
