---
title: Quick Start Guide
description: Get up and running with docker-mariadb-snapshot in 5 minutes with Docker CLI, Docker Compose, and cron scheduling examples
audience: users
doc_type: quickstart
tags: [quickstart, getting-started, docker, docker-compose, cron]
lastReviewed: 2025-11-15
version: 1.x
---

# Quick Start Guide

Get up and running with docker-mariadb-snapshot in 5 minutes.

!!! warning "Your Responsibility"
    Please review the [Important Considerations](important-considerations.md) document. This package has not been reviewed for all possible use cases and environments. It should be considered an example, rather than a production-ready tool. Please ensure that you audit this package and how you deploy it against your specific environment and requirements.

## Basic Usage

docker-mariadb-rsnapshot accepts one argument to specify the snapshot frequency:

- `hourly` - Performs an hourly snapshot
- `daily` - Performs a daily snapshot
- `weekly` - Performs a weekly snapshot
- `monthly` - Performs a monthly snapshot

These are labels passed to rsnapshot, which handles snapshot rotation based on your retention configuration.

## Docker Run Example

Here's a minimal example backing up a single database:

```bash
docker run --rm \
  -e DB_HOSTNAME=mysql.example.com \
  -e DB_PORT=3306 \
  -e DB_USER_NAME=snapshot_user \
  -e DB_USER_PASSWORD=secure_password \
  -e DB_DATABASE=myapp \
  -v /path/to/snapshots:/data \
  jacobsanford/docker-mariadb-snapshot:1.x hourly
```

This creates a snapshot in `/path/to/snapshots/hourly.0/mysql/myapp.gz`.

## Docker Compose Quick Example

Create a `docker-compose.yml`:

```yaml
services:
  mariadb-snapshot:
    image: jacobsanford/docker-mariadb-snapshot:1.x
    restart: "no"
    environment:
      DB_HOSTNAME: mysql
      DB_PORT: 3306
      DB_USER_NAME: root
      DB_USER_PASSWORD: changeme
      DB_DATABASE: myapp
    volumes:
      - ./snapshots:/data
```

Run a snapshot:

```bash
docker compose run --rm mariadb-snapshot hourly
```

### Scheduling with Cron

To run automated snapshots, add to your [crontab](https://man7.org/linux/man-pages/man5/crontab.5.html){target="_blank"}:

```bash
# Hourly snapshots at minute 0
0 * * * * cd /path/to/compose && docker compose run --rm mariadb-snapshot hourly

# Daily snapshots at 2am
0 2 * * * cd /path/to/compose && docker compose run --rm mariadb-snapshot daily

# Weekly snapshots on Sunday at 3am
0 3 * * 0 cd /path/to/compose && docker compose run --rm mariadb-snapshot weekly

# Monthly snapshots on the 1st at 4am
0 4 1 * * cd /path/to/compose && docker compose run --rm mariadb-snapshot monthly
```

## Understanding Snapshot Output

Snapshots are rotated and stored in timestamped snapshot directories per [rsnapshot conventions](https://wiki.archlinux.org/title/Rsnapshot){target="_blank"}:

```
/data/
├── hourly.0/    # Most recent hourly snapshot
│   └── mysql/
│       └── myapp.gz
├── hourly.1/    # Previous hourly snapshot
├── hourly.2/
├── daily.0/     # Most recent daily snapshot
│   └── mysql/
│       └── myapp.gz
├── daily.1/
└── weekly.0/    # Most recent weekly snapshot
    └── mysql/
        └── myapp.gz
```

The `.0` directories contain the newest snapshots. Older snapshots are rotated to `.1`, `.2`, etc., based on your retention policy.

## Next Steps

- **[Configuration](configuration.md)** - Learn about all environment variables and snapshot modes
- **[Docker Compose Examples](docker-compose.md)** - See examples for all snapshot modes
- **[Kubernetes](kubernetes.md)** - Deploy with CronJob for automated scheduling
