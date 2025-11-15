#!/usr/bin/env sh
# Export all DB_STRUCT_TABLES_* environment variables so they're available to the snapshot script
# This allows per-database structure-only table configuration
export $(env | grep '^DB_STRUCT_TABLES_' || true)
