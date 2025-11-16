---
title: Snapshot Metadata
description: Understanding the snapshot-metadata.json file generated with each backup operation
audience: users
doc_type: reference
tags: [metadata, json, snapshot-info, configuration, troubleshooting]
lastReviewed: 2025-11-16
version: 1.x
---

# Snapshot Metadata

Each snapshot run automatically generates a `snapshot-metadata.json` file containing detailed information about the backup operation. This file is stored alongside your database backups and rotated with them by rsnapshot.

**Metadata Contents:**

The JSON file includes the following information:

- **Snapshot Information**: Start time, end time, duration (seconds), and frequency (hourly/daily/weekly/monthly)
- **Database Server**: Server type (MariaDB/MySQL), version, and version comment (e.g., "MySQL Community Server - GPL" or "MariaDB Server")
- **Client Information**: MariaDB dump utility version
- **Configuration**: Key environment variables used for the snapshot (excluding authentication details)

**Example metadata file:**
```json
{
  "snapshot_info": {
    "start_time": "2025-11-15T12:34:56Z",
    "end_time": "2025-11-15T12:35:23Z",
    "duration_seconds": 27,
    "frequency": "hourly"
  },
  "database_server": {
    "type": "MySQL",
    "version": "8.0.44",
    "version_comment": "MySQL Community Server - GPL"
  },
  "client_info": {
    "mariadb_dump_version": "mariadb-dump 11.4.8-MariaDB"
  },
  "configuration": {
    "DB_HOSTNAME": "mysql",
    "DB_PORT": "3306",
    "DB_DATABASES": "app1,app2",
    "RSNAPSHOT_RETAIN_HOURLY": "24",
    "GZIP_COMPRESSION_LEVEL": "9"
  }
}
```

**Security Note:** The metadata file excludes sensitive information like `DB_USER_NAME` and `DB_USER_PASSWORD`.
