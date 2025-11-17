---
title: Backup Consistency and Atomic State
description: Understanding consistency guarantees and limitations of backups created with --single-transaction and --skip-lock-tables
audience: users
doc_type: reference
tags: [consistency, atomic-state, storage-engines, innodb, myisam, transactions, data-integrity]
lastReviewed: 2025-11-17
version: 1.x
---

# Backup Consistency and Atomic State

The combination of `--single-transaction` and `--skip-lock-tables` provides point-in-time consistency for **InnoDB tables only**. Non-transactional storage engines are not protected.

## Consistency by Storage Engine

### InnoDB (✅ Consistent)

- All tables captured at the same transaction timestamp
- Data relationships remain intact (e.g., orders match order items)
- Non-blocking - reads and writes continue during backup

### MyISAM, MEMORY, CSV, Archive (⚠️ Inconsistent)

- Tables are not locked during backup
- May be captured mid-modification
- Can contain mixed old and new data that never existed together
- Mixed InnoDB + MyISAM databases will have tables from different points in time

## Check Your Storage Engines

Run this query to see which storage engines your databases use:

```sql
SELECT TABLE_SCHEMA, ENGINE, COUNT(*) AS tables
FROM information_schema.TABLES
WHERE TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
GROUP BY TABLE_SCHEMA, ENGINE;
```

**Interpretation:**

- ✅ **All InnoDB**: Backups are consistent - current configuration is optimal
- ⚠️ **Mixed engines**: Backups may be inconsistent across tables
- ⚠️ **Mostly MyISAM**: No consistency guarantees

## Recommendations

**All InnoDB databases:** Continue using current configuration.

**Mixed InnoDB + MyISAM:**

1. Migrate MyISAM to InnoDB (recommended)
2. Use read-only mode during backups (see [Important Considerations](important-considerations.md#read-only-mode-current-tool){target="_blank"})
3. Modify to use `--lock-all-tables` (requires downtime)

**Mostly MyISAM databases:**

- Use `--lock-all-tables` with scheduled maintenance windows
- Consider migrating to InnoDB
- Backup from replica to isolate production impact

## Additional Limitations

**Binary log position:** Not captured by default. Point-in-time recovery and replica setup require manual binary log analysis. To capture position, modify `build/scripts/snapshot.sh` to add `--master-data` flag.

**Testing:** Always restore backups to a test environment to verify consistency meets your requirements. See [Restoration Guide](restoration.md){target="_blank"}.
