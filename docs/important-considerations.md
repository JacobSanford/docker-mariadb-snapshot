---
title: Important Considerations
description: Critical security, data integrity, and operational considerations for using docker-mariadb-snapshot in production
audience: users
doc_type: reference
tags: [security, best-practices, considerations, production, data-integrity, performance, backup-strategies]
lastReviewed: 2025-11-17
version: 1.x
---

# Important Considerations

!!! info "Please Read"
    These considerations are provided to help you evaluate the suitability of docker-mariadb-snapshot for your specific environment and requirements, not to scare you away from using it.

    This tool has succesfully been used in production with mid-scale (1M+ rows) deployments, but every environment is different.

docker-mariadb-snapshot may not be suitable for all environments. It is designed to be reliable, simple and easy to use. It may not meet all requirements or constraints in every scenario.

Please ensure that you audit this package and understand its limitations before deploying it in your specific environment. Some of the considerations you may want to review before deploying this package in production include:

## Testing Snapshot Restorations
Always test restoration procedures __immediately after scheduling and performing the first snapshots__.

- Test in a non-production environment.
- Verify the snapshot integrity and compatibility with your target server version by performing the restoration as if you were in a data-loss situation.

If possible, automate periodic restoration tests to ensure ongoing snapshot integrity.

## Sensitive Data
Database snapshots may contain sensitive, personal, or confidential data. Snapshots are plain-text and, unless encrypted separately, insecure by default. Ensure that snapshot files are stored securely and access is restricted.

## Non-Default rsnapshot Configuration
By default, rsnapshot uses a rotation mechanism to manage snapshots in a hierarchy. docker-mariadb-snapshot instead leverages the `sync_first     1` rsnapshot configuration item.

Consequently, running docker-mariadb-snapshot with any frequency level as an argument __will always snapshot the live data before performing the rotation__, and rotation only happens within the level you invoke. See the [Understanding the RSnapshot Configuration](rsnapshot.md) document for more details.

## Container Restart Policies
The image ENTRYPOINT will return a non-zero exit code if any part of the snapshot process fails (even if only one database snapshot in many fails).

This means: If only one database in an entire snapshot failed to snapshot, docker-mariadb-snapshot will still signal the orchestration system that the run has failed. This allows observability and notification of snapshot issues.

Other databases/users may have successfully snapshotted during such a failed run. To err on the side of caution, __a partial snapshot failure is still post-processed as if it were successful__ - rotation will occur, and the snapshot files created during that run will be retained according to your retention policies.

A consequence of this: if a snapshot fails and docker-mariadb-snapshot exits with a non-zero status, a container restart policy like `always` or `on-failure` could cause a cascading string of restarts and failed snapshots, overwriting many retained 'good' snapshots with the current failure.

Although all examples within this documentation set docker-mariadb-snapshot restart policy to prevent automatic restarts on failure, it is important to ensure that your orchestration system or container runtime is configured similarly to handle these scenarios appropriately.

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

## MariaDB Sandbox Mode
Recent versions of `mariadb-dump` introduced **sandbox mode** as a security feature and now prepend a special directive at the top of every dump file:


```sql
/*!999999- enable the sandbox mode */
```

The change was introduced as a mitigation for [CVE-2024-21096](https://nvd.nist.gov/vuln/detail/cve-2024-21096). Sandbox mode blocks those dangerous client commands, but it also has a side effect: **older MariaDB clients and all MySQL clients do not understand the `\-` sandbox command and fail with errors like `ERROR at line 1: Unknown command '\-'` when they encounter this directive**. For more details, see[ MariaDB’s announcement “MariaDB Dump File Compatibility Change](https://mariadb.org/mariadb-dump-file-compatibility-change/).

docker-mariadb-snapshot strips this line by default from all dump files after they are created to maintain compatibility with older MariaDB clients and MySQL clients. If you want to retain this line in your dumps, set the environment variable `STRIP_SANDBOX_MODE_COMMENT` to `false`.

## Snapshot Consistency and Atomic State
### Overview
The combination of `--single-transaction` and `--skip-lock-tables` provides **point-in-time consistency for InnoDB tables only**.  Generally, this is likely 'good enough' for many applications using InnoDB as the primary storage engine. Non-transactional storage engines (MyISAM, MEMORY, etc.) are not locked and may be captured in an inconsistent state if modified during snapshot.

For more detailed information about consistency, storage engine implications, cross-engine consistency issues, and how to audit your database, see the [Snapshot Consistency and Atomic State](consistency.md) guide.

## High Confidence Snapshot Consistency
For high-reliability snapshots, a [MariaDB](https://mariadb.org){target="_blank"}/[MySQL](https://www.mysql.com){target="_blank"} server should be placed into a read-only state before the snapshot is taken.

How to do so is outside the scope of this documentation, and depends on your specific environment and setup.

Good starting points:

* [Backing Up a Source or Replica by Making It Read Only – MySQL Reference Manual](https://dev.mysql.com/doc/refman/8.4/en/replication-solutions-backups-read-only.html){target="_blank"}
