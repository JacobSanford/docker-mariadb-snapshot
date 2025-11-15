---
title: Important Considerations
description: Critical security, data integrity, and operational considerations for using docker-mariadb-snapshot in production
audience: users
doc_type: reference
tags: [security, best-practices, considerations, production, data-integrity]
lastReviewed: 2025-11-15
version: 1.x
---

# Important Considerations
This package has not been reviewed for all possible use cases and environments. It should be considered an example rather than a production-ready tool.
Please be aware of the following considerations:

## Your Environment
This package may not be suitable for all environments. Please ensure that you audit this package and how you deploy it against your specific environment and requirements.

## Sensitive Data
Database snapshots may contain sensitive, personal, or confidential data. Ensure that snapshot files are stored securely and access is restricted.

## Container Restart Policies
The image ENTRYPOINT will return a non-zero exit code if any part of the snapshot process fails (even if only one database snapshot in many fails).

This means: If only one database in an entire backup failed to snapshot, the container will still signal the orchestration system that the run has failed. This allows observability and notification of snapshot issues.

Other databases/users may have successfully snapshotted during such a failed run. To err on the side of caution, __a partial snapshot failure is still post-processed as if it were successful__ - rotation will occur, and the snapshot files created during that run will be retained according to your retention policies.

A consequence of this: if a snapshot fails and the container exits with a non-zero status, a container restart policy like `always` or `on-failure` could cause a cascading string of restarts and failed snapshots, ovewriting many retained 'good' snapshots with the current failure.

Although all examples within this documentation set the container restart policy to prevent automatic restarts on failure, it is important to ensure that your orchestration system or container runtime is configured similarly to handle these scenarios appropriately.

### Suggested Configurations
#### docker-compose
Setting the [restart policy](https://docs.docker.com/reference/compose-file/services/#restart){target="_blank"} to "no" will prevent automatic restarts:
```yaml
service:
    [...]
    restart: "no"
```

#### Kubernetes Cron
Setting the [restartPolicy](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#restart-policy){target="_blank"} to `Never` and [backoffLimit](https://kubernetes.io/docs/concepts/workloads/controllers/job/#job-backoff-limit){target="_blank"} to `0` in a Job spec will prevent automatic restarts:

```yaml
    restartPolicy: Never
    backoffLimit: 0
```

## Snapshot Options
The [mariadb-dump](https://mariadb.com/kb/en/mariadb-dump/){target="_blank"} utility has many options, however only the following are used to create snapshots:

```bash
    --single-transaction
    --quick
    --skip-lock-tables
    --routines
    --events
    --triggers
    --hex-blob
    --default-character-set=${DB_DEFAULT_CHARSET}
```

The character set defaults to `utf8mb4` but can be customized via the `DB_DEFAULT_CHARSET` environment variable.

If you require additional options, you will need to modify the package accordingly.

## Data Integrity
For high-reliability snapshots, a [MariaDB](https://mariadb.org){target="_blank"}/[MySQL](https://www.mysql.com){target="_blank"} server must be placed into a read-only state before the snapshot is taken.

How to do so is outside the scope of this documentation, and depends on your specific environment and setup.

Good starting points:

* [Backing Up a Source or Replica by Making It Read Only – MySQL Reference Manual](https://dev.mysql.com/doc/refman/8.4/en/replication-solutions-backups-read-only.html){target="_blank"}
