---
title: Restoring Snapshots
description: Guide for restoring database snapshots and user accounts from docker-mariadb-snapshot backups
audience: users
doc_type: guide
tags: [restore, recovery, mysql, mariadb, backup, users, grants]
lastReviewed: 2025-11-15
version: 1.x
---

# Restoring Snapshots

This guide covers basic restoration of database snapshots and user accounts created by docker-mariadb-snapshot.

!!! warning "Test Restorations First"
    Always test restoration procedures in a non-production environment before performing them on production systems. Verify backup integrity and compatibility with your target server version.

## What Can Be Restored

Snapshot backups include:

- **Database dumps** (`.gz` files) - Database schemas, tables, data, routines, events, and triggers
- **User accounts** (`users.sql.gz`) - User definitions, passwords, and grant permissions (if `DB_SNAPSHOT_USERS_GRANTS` was enabled)
- **Metadata** (`snapshot-metadata.json`) - Information about the snapshot including server type, version, and configuration

**Note:** Structure-only tables (like cache or session tables) are restored with schema only - no data.

## Restoring Database Data

### Single Database Restoration

To restore a single database from a snapshot:

```bash
# Using local mysql client
gunzip -c /path/to/snapshots/hourly.0/mysql/myapp.gz | mysql -h localhost -u root -p

# Using Docker to restore to a containerized MySQL server
gunzip -c /path/to/snapshots/hourly.0/mysql/myapp.gz | \
  docker exec -i mysql-server mysql -u root -p[password]
```

### Multiple Databases

Restore multiple databases by repeating the process for each `.gz` file:

```bash
# Restore app1, app2, app3
for db in app1 app2 app3; do
  echo "Restoring $db..."
  gunzip -c /path/to/snapshots/hourly.0/mysql/${db}.gz | mysql -h localhost -u root -p
done
```

### Combined Backup (ALL_DATABASES.gz)

If you used `DB_SNAPSHOT_COMBINED=true`, restore all databases from a single file:

```bash
gunzip -c /path/to/snapshots/hourly.0/mysql/ALL_DATABASES.gz | mysql -h localhost -u root -p
```

## Restoring Users and Grants

If `DB_SNAPSHOT_USERS_GRANTS` was enabled, restore user accounts and permissions:

```bash
# Using local mysql client
gunzip -c /path/to/snapshots/hourly.0/mysql/users.sql.gz | mysql -h localhost -u root -p

# Using Docker
gunzip -c /path/to/snapshots/hourly.0/mysql/users.sql.gz | \
  docker exec -i mysql-server mysql -u root -p[password]
```

**Important:** User restoration requires administrative privileges on the target server (typically `root` or equivalent).

## Verification

After restoration, verify the data:

```bash
# Check databases exist
mysql -h localhost -u root -p -e "SHOW DATABASES;"

# Verify table row counts
mysql -h localhost -u root -p myapp -e "SELECT COUNT(*) FROM users;"

# Check users and grants
mysql -h localhost -u root -p -e "SELECT user, host FROM mysql.user;"
```

## Examining Snapshots

To inspect snapshot contents before restoring:

```bash
# View SQL without executing
gunzip -c myapp.gz | less

# Check file integrity
gunzip -t myapp.gz && echo "File is valid"

# Review metadata
cat snapshot-metadata.json | jq .
```

## Important Considerations

**Server Compatibility:**

- Check `snapshot-metadata.json` for source server type and version
- [MariaDB](https://mariadb.com){target="_blank"} and [MySQL](https://www.mysql.com){target="_blank"} have some incompatibilities
- Major version differences may cause issues

**Existing Data:**

- The snapshots use `--add-drop-table` flag, which **drops existing tables** before recreating them
- Back up your target database before restoring if it contains data you want to preserve

## Related Documentation

- [Configuration Reference](configuration.md) - Environment variables and snapshot settings
- [Important Considerations](important-considerations.md) - Security and data integrity notes
- [Snapshot Metadata](configuration.md#snapshot-metadata) - Understanding metadata files
