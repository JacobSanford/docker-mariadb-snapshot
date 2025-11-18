---
title: Compatibility
description: MariaDB and MySQL version compatibility for docker-mariadb-snapshot exports and imports
audience: users
doc_type: reference
tags: [compatibility, mariadb, mysql, versions]
lastReviewed: 2025-11-15
version: 1.x
---

# Compatibility

This image leverages `mariadb-dump` for database exports, which is compatible with both MariaDB and MySQL servers.

## Export Compatibility
Tested and expected to export snapshots from:

- MariaDB 10.5+ (10.5/10.6/10.11/11.x/12.x)
- MySQL 5.6+, 5.7, and 8.x

## Import Compatibility
Snapshots created by docker-mariadb-snapshot can be imported into:

- MariaDB 10.5+ (10.5/10.6/10.11/11.x/12.x)
- MySQL 5.6+, 5.7, and 8.x

## Older Versions
While older versions of MariaDB and MySQL may work, they have not been explicitly tested with docker-mariadb-snapshot. If you are using significantly older versions, please test snapshot exports and imports in a non-production environment to ensure compatibility. 

!!! warning "MariaDB Sandbox Mode Compatibility"
    Please see the [Important Considerations](important-considerations.md) document for details on MariaDB sandbox mode and compatibility with MySQL clients. If you are only using modern MariaDB servers and clients, you may want to disable the docker-mariadb-snapshot default behavior of stripping the sandbox mode comment from dumps.
