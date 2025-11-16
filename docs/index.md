---
title: docker-mariadb-snapshot Documentation
description: Docker image for periodic MariaDB/MySQL database snapshots with rotation using rsnapshot
audience: users
doc_type: landing
tags: [mysql, mariadb, backup, snapshot, rsnapshot, docker, database]
lastReviewed: 2025-11-15
version: 1.x
---

# docker-mariadb-snapshot Documentation

<p align="center">
  <img src="images/logo.png" alt="docker-mariadb-snapshot logo">
</p>

[![CI](https://github.com/JacobSanford/docker-mariadb-snapshot/actions/workflows/ci.yml/badge.svg)](https://github.com/JacobSanford/docker-mariadb-snapshot/actions/workflows/ci.yml){target="_blank"}

A [Docker](https://www.docker.com){target="_blank"} image that wraps [mariadb-dump](https://mariadb.org){target="_blank"}/[mysqldump](https://www.mysql.com){target="_blank"} and [rsnapshot](https://rsnapshot.org){target="_blank"} to provide a drop-in solution for periodic snapshots of MariaDB/MySQL databases with automated rotation and retention.

The primary goals of docker-mariadb-snapshot are reliability, simplicity, and ease of use.

!!! warning "Your Responsibility"
    Please review the [Important Considerations](important-considerations.md) document. This package has not been reviewed for all possible use cases and environments. It should be considered an example, rather than a production-ready tool. Please ensure that you audit this package and how you deploy it against your specific environment and requirements.

## Quick Navigation

- **[Quick Start Guide](quickstart.md)** - Get up and running in 5 minutes
- **[Configuration Reference](configuration.md)** - Complete environment variable documentation
- **[Restoring Snapshots](restoration.md)** - Guide for restoring database snapshots and users
- **[Docker Compose Examples](docker-compose.md)** - Sample configurations for all snapshot modes
- **[Kubernetes Deployment](kubernetes.md)** - CronJob and volume configurations
- **[Running Tests](running-tests.md)** - Developer guide to testing

## How It Works

The image leverages [`rsnapshot`](https://rsnapshot.org){target="_blank"} for snapshot rotation and [`mariadb-dump`](https://mariadb.com/kb/en/mariadb-dump/){target="_blank"} for database exports. When run with a frequency argument (`hourly`, `daily`, `weekly`, `monthly`), it:

1. Connects to your MariaDB/MySQL server
2. Selects databases based on your configuration mode
3. Applies structure-only table rules if configured
4. Dumps each database to a .sql file, applying compression if configured
5. Generates a `snapshot-metadata.json` file with snapshot details, timing, and configuration
6. Rotates snapshots according to retention policies
7. Stores snapshots in timestamped directories (e.g., `hourly.0/`, `hourly.1/`)

## License

This project is licensed under the MIT License.
