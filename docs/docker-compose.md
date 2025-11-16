---
title: Docker Compose Examples
description: Sample Docker Compose configurations for all backup modes including single database, multiple databases, auto-discovery, and structure-only tables
audience: users
doc_type: guide
tags: [docker-compose, examples, deployment, configuration]
lastReviewed: 2025-11-15
version: 1.x
---

# Docker Compose Examples

This page provides [Docker Compose](https://docs.docker.com/compose/){target="_blank"} examples.

!!! warning "Your Responsibility"
    Please review the [Important Considerations](important-considerations.md) document. This package has not been reviewed for all possible use cases and environments. It should be considered an example, rather than a production-ready tool. Please ensure that you audit this package and how you deploy it against your specific environment and requirements.

## Drop-In Example

A full Docker Compose setup with MySQL server and backup service:

```yaml
services:
  mysql:
    [...]

  # Backup service
  mariadb-snapshot:
    image: jacobsanford/docker-mariadb-snapshot:latest
    restart: "no"
    environment:
      DB_HOSTNAME: mysql
      DB_PORT: 3306
      DB_USER_NAME: root
      DB_USER_PASSWORD: changeme
      DB_SNAPSHOT_ALL_DATABASES: "true"
      DB_SNAPSHOT_COMBINED: "true"
      RSNAPSHOT_RETAIN_HOURLY: 24
      RSNAPSHOT_RETAIN_DAILY: 14
      RSNAPSHOT_RETAIN_WEEKLY: 8
      RSNAPSHOT_RETAIN_MONTHLY: 12
      GZIP_COMPRESSION_LEVEL: 9
    volumes:
      - ./snapshots:/data
    depends_on:
      mysql:
        condition: service_healthy

volumes:
  mysql-data:
```

## Other Examples
### Multiple Specific Databases

Backs up a specific list of databases. Each database is backed up to a separate file.

```yaml
services:
  mysql:
    [...]

  mariadb-snapshot:
    image: jacobsanford/docker-mariadb-snapshot:latest
    restart: "no"
    environment:
      DB_HOSTNAME: mysql
      DB_PORT: 3306
      DB_USER_NAME: root
      DB_USER_PASSWORD: rootpassword
      DB_DATABASES: "app1,app2,app3"
      DB_STRUCT_TABLES: "cache_*,sessions"
    volumes:
      - ./snapshots:/data
```

### All Databases

Automatically discovers and backs up all non-system databases.

```yaml
services:
  mysql:
    [...]

  mariadb-snapshot:
      image: jacobsanford/docker-mariadb-snapshot:latest
      restart: "no"
      environment:
        DB_HOSTNAME: mysql
        DB_PORT: 3306
        DB_USER_NAME: root
        DB_USER_PASSWORD: rootpassword
        DB_SNAPSHOT_ALL_DATABASES: "true"
        DB_EXCLUDE_DATABASES: "information_schema,performance_schema,mysql,sys"
      volumes:
        - ./snapshots:/data
```

### With Structure-Only Tables Per Database

Different structure-only table patterns for each database.

```yaml
services:
  mysql:
    [...]

  mariadb-snapshot:
    image: jacobsanford/docker-mariadb-snapshot:latest
    restart: "no"
    environment:
      DB_HOSTNAME: mysql
      DB_PORT: 3306
      DB_USER_NAME: root
      DB_USER_PASSWORD: rootpassword
      DB_DATABASES: "app1,app2"

      # Per-database structure-only tables
      DB_STRUCT_TABLES_APP1: "cache_*,sessions,watchdog"
      DB_STRUCT_TABLES_APP2: "temp_*,cache"

      # Retention policy
      RSNAPSHOT_RETAIN_HOURLY: 24
      RSNAPSHOT_RETAIN_DAILY: 7
      RSNAPSHOT_RETAIN_WEEKLY: 4
      RSNAPSHOT_RETAIN_MONTHLY: 12
    volumes:
      - ./snapshots:/data
```

## Running Backups

All examples use the same pattern:

```bash
docker compose run --rm <service-name> <frequency>
```

Where `<frequency>` is one of: `hourly`, `daily`, `weekly`, `monthly`

## Next Steps

- **[Configuration Reference](configuration.md)** - Detailed environment variable documentation
- **[Kubernetes Examples](kubernetes.md)** - Deploy with CronJob for automated scheduling
