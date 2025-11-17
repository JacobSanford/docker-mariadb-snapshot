---
title: Backup Consistency and Atomic State
description: Understanding consistency guarantees and limitations of backups created with --single-transaction and --skip-lock-tables
audience: users
doc_type: reference
tags: [consistency, atomic-state, storage-engines, innodb, myisam, transactions, data-integrity]
lastReviewed: 2025-11-17
version: 1.x
---

# Snapshot Consistency and Atomic State

The combination of `--single-transaction` and `--skip-lock-tables` provides point-in-time consistency for **InnoDB tables only**. Non-transactional storage engines are not guaranteeed to be consistent. This is generally 'good enough' for non-critical services leveraging InnoDB - the fact that you are considering using this package indicates that you likely do not require fully ACID-compliant backups.

## Consistency by Storage Engine

### InnoDB (✅ Consistent)

- All tables captured at the same transaction timestamp
- Data relationships remain intact (e.g., orders match order items)
- Non-blocking - reads and writes continue during snapshot

### MyISAM, MEMORY, CSV, Archive (⚠️ Inconsistent)

- Tables are not locked during snapshot
- May be captured mid-modification
- Can contain mixed old and new data that never existed together
- Mixed InnoDB + MyISAM databases will have tables from different points in time

## Additional Limitations

**Binary log position:** Not captured by default. Point-in-time recovery and replica setup require manual binary log analysis. To capture position, modify `build/scripts/snapshot.sh` to add `--master-data` flag.

**Testing:** Always restore snapshots to a test environment to verify consistency meets your requirements. See [Restoration Guide](restoration.md).
