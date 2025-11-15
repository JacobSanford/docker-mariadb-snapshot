#!/usr/bin/env sh
set -e

MYSQLDUMP=/usr/bin/mariadb-dump
SNAPSHOTS_FAILED=0

# Resolves existing table names based on MySQL wildcard patterns
resolve_tables() {
  database="$1"
  pattern="$2"  # e.g., cache_%
  mysql \
    --skip-ssl \
    --host="${DB_HOSTNAME}" \
    --port="${DB_PORT}" \
    --user="${DB_USER_NAME}" \
    --password="${DB_USER_PASSWORD}" \
    --batch --skip-column-names \
    -e "SHOW TABLES LIKE '${pattern}';" "$database" 2>/dev/null || true
}

# Normalize database name for environment variable lookup
# e.g., "my-db" -> "MY_DB", "my.db" -> "MY_DB"
normalize_db_name() {
  echo "$1" | tr '[:lower:]' '[:upper:]' | tr '-' '_' | tr '.' '_'
}

# Get MariaDB client version
get_client_version() {
  $MYSQLDUMP --version 2>/dev/null | head -1 || echo "unknown"
}

# Get database server version
get_server_version() {
  mysql \
    --skip-ssl \
    --host="${DB_HOSTNAME}" \
    --port="${DB_PORT}" \
    --user="${DB_USER_NAME}" \
    --password="${DB_USER_PASSWORD}" \
    --batch --skip-column-names \
    -e "SELECT VERSION();" 2>/dev/null || echo "unknown"
}

# Get database server type (MariaDB or MySQL)
get_server_type() {
  mysql \
    --skip-ssl \
    --host="${DB_HOSTNAME}" \
    --port="${DB_PORT}" \
    --user="${DB_USER_NAME}" \
    --password="${DB_USER_PASSWORD}" \
    --batch --skip-column-names \
    -e "SELECT @@version_comment;" 2>/dev/null || echo "unknown"
}

# Generate snapshot metadata JSON file
generate_metadata_json() {
  START_TIME=$1
  END_TIME=$2
  DURATION=$3
  FREQUENCY=${SNAPSHOT_FREQUENCY:-unknown}

  # Get version information
  CLIENT_VERSION=$(get_client_version)
  SERVER_VERSION=$(get_server_version)
  SERVER_TYPE_COMMENT=$(get_server_type)

  # Determine server type from version_comment
  if echo "$SERVER_TYPE_COMMENT" | grep -qi "mariadb"; then
    SERVER_TYPE="MariaDB"
  elif echo "$SERVER_TYPE_COMMENT" | grep -qi "mysql"; then
    SERVER_TYPE="MySQL"
  else
    SERVER_TYPE="unknown"
  fi

  # Create JSON metadata file
  cat > ./snapshot-metadata.json <<EOF
{
  "snapshot_info": {
    "start_time": "$START_TIME",
    "end_time": "$END_TIME",
    "duration_seconds": $DURATION,
    "frequency": "$FREQUENCY"
  },
  "database_server": {
    "type": "$SERVER_TYPE",
    "version": "$SERVER_VERSION",
    "version_comment": "${SERVER_TYPE_COMMENT:-unknown}"
  },
  "client_info": {
    "mariadb_dump_version": "$CLIENT_VERSION"
  },
  "configuration": {
    "DB_HOSTNAME": "${DB_HOSTNAME:-}",
    "DB_PORT": "${DB_PORT:-}",
    "DB_DATABASES": "${DB_DATABASES:-}",
    "DB_SNAPSHOT_ALL_DATABASES": "${DB_SNAPSHOT_ALL_DATABASES:-}",
    "DB_SNAPSHOT_COMBINED": "${DB_SNAPSHOT_COMBINED:-}",
    "DB_SNAPSHOT_USERS_GRANTS": "${DB_SNAPSHOT_USERS_GRANTS:-}",
    "DB_EXCLUDE_DATABASES": "${DB_EXCLUDE_DATABASES:-}",
    "DB_DEFAULT_CHARSET": "${DB_DEFAULT_CHARSET:-}",
    "DB_STRUCT_TABLES": "${DB_STRUCT_TABLES:-}",
    "RSNAPSHOT_RETAIN_HOURLY": "${RSNAPSHOT_RETAIN_HOURLY:-}",
    "RSNAPSHOT_RETAIN_DAILY": "${RSNAPSHOT_RETAIN_DAILY:-}",
    "RSNAPSHOT_RETAIN_WEEKLY": "${RSNAPSHOT_RETAIN_WEEKLY:-}",
    "RSNAPSHOT_RETAIN_MONTHLY": "${RSNAPSHOT_RETAIN_MONTHLY:-}",
    "GZIP_COMPRESSION_LEVEL": "${GZIP_COMPRESSION_LEVEL:-}"
  }
}
EOF
}

# Backup a single database
snapshot_single_database() {
  DB_NAME="$1"
  echo "=================================================="
  echo "Backing up database: $DB_NAME"
  echo "=================================================="

  # Check for database-specific structure-only tables
  # Format: DB_STRUCT_TABLES_<NORMALIZED_DB_NAME>
  NORMALIZED_NAME=$(normalize_db_name "$DB_NAME")

  # Try to get per-database structure-only tables
  # Use eval to dynamically access the variable (disable -e temporarily to handle unset vars)
  STRUCTURE_ONLY_TABLES=""
  VAR_NAME="DB_STRUCT_TABLES_${NORMALIZED_NAME}"
  set +e
  eval "STRUCTURE_ONLY_TABLES=\${${VAR_NAME}}" 2>/dev/null
  set -e

  # If no per-database config, fall back to global DB_STRUCT_TABLES
  if [ -z "$STRUCTURE_ONLY_TABLES" ]; then
    STRUCTURE_ONLY_TABLES="${DB_STRUCT_TABLES}"
  fi

  # Paths for temp files
  TMP_SCHEMA="/tmp/schema_${DB_NAME}.sql"
  TMP_DATA="/tmp/data_${DB_NAME}.sql"
  TMP_COMBINED="/tmp/${DB_NAME}"
  IGNORE_TABLES_FULL_DUMP_CMD=""

  # 1. Dump schema-only for structure tables if specified
  if [ -n "$STRUCTURE_ONLY_TABLES" ]; then
    echo "Resolving structure-only tables for $DB_NAME..."
    STRUCTURE_ONLY_PATTERNS=$(echo "$STRUCTURE_ONLY_TABLES" | tr ',' ' ' | tr '*' '%')
    STRUCTURE_ONLY_TABLES_EXPANDED=""
    for pattern in $STRUCTURE_ONLY_PATTERNS; do
      TABLES=$(resolve_tables "$DB_NAME" "$pattern")
      if [ -n "$TABLES" ]; then
        STRUCTURE_ONLY_TABLES_EXPANDED="$STRUCTURE_ONLY_TABLES_EXPANDED $TABLES"
      fi
    done
    # Remove leading/trailing whitespace
    STRUCTURE_ONLY_TABLES_EXPANDED=$(echo "$STRUCTURE_ONLY_TABLES_EXPANDED" | xargs)

    if [ -n "$STRUCTURE_ONLY_TABLES_EXPANDED" ]; then
      echo "✅ Resolved structure-only tables for $DB_NAME: [$STRUCTURE_ONLY_TABLES_EXPANDED]"

      echo "Dumping schema for structure tables..."
      $MYSQLDUMP \
        --skip-ssl \
        --host="${DB_HOSTNAME}" \
        --port="${DB_PORT}" \
        --user="${DB_USER_NAME}" \
        --password="${DB_USER_PASSWORD}" \
        --add-drop-table \
        --no-data \
        --routines \
        --events \
        --triggers \
        --default-character-set=${DB_DEFAULT_CHARSET} \
        --databases "$DB_NAME" \
        --tables \
        $STRUCTURE_ONLY_TABLES_EXPANDED > "$TMP_SCHEMA"
      echo "✅ Dumped schema for structure tables to: $TMP_SCHEMA"

      # Prepare ignore tables command for full dump
      IGNORE_TABLES_FULL_DUMP_CMD=$(echo "$STRUCTURE_ONLY_TABLES_EXPANDED" | sed "s/ / --ignore-table=${DB_NAME}./g" | sed "s/^/--ignore-table=${DB_NAME}./")
      echo "Prepared ignore tables command for full dump: [$IGNORE_TABLES_FULL_DUMP_CMD]"
    else
      echo "No matching structure-only tables found for $DB_NAME"
    fi
  fi

  # 2. Dump full DB (or DB minus structure tables)
  echo "Dumping full database $DB_NAME..."
  if ! $MYSQLDUMP \
    --skip-ssl \
    --host="${DB_HOSTNAME}" \
    --port="${DB_PORT}" \
    --user="${DB_USER_NAME}" \
    --password="${DB_USER_PASSWORD}" \
    --add-drop-table \
    --single-transaction \
    --quick \
    --skip-lock-tables \
    --routines \
    --events \
    --triggers \
    --hex-blob \
    --default-character-set=${DB_DEFAULT_CHARSET} \
    $IGNORE_TABLES_FULL_DUMP_CMD \
    "$DB_NAME" > "$TMP_DATA" 2>&1; then
    echo "❌ ERROR: Failed to dump database: $DB_NAME"
    echo "Error output:"
    head -200 "$TMP_DATA" 2>/dev/null || echo "(no error output captured)"
    rm -f "$TMP_SCHEMA" "$TMP_DATA" "$TMP_COMBINED"
    return 1
  fi
  echo "✅ Dumped full database to: $TMP_DATA"

  # 3. Combine schema and data dumps if structure-only tables were found
  if [ -f "$TMP_SCHEMA" ]; then
    echo "Combining schema and data dumps for $DB_NAME..."
    cat "$TMP_SCHEMA" "$TMP_DATA" > "$TMP_COMBINED"
  else
    mv "$TMP_DATA" "$TMP_COMBINED"
  fi

  # 4. Strip lines containing "enable the sandbox mode" for compatibility with old versions
  # See: https://github.com/drush-ops/drush/issues/6027
  sed -i '/enable the sandbox mode/d' "$TMP_COMBINED"

  # 4.5. Append to combined backup file if it exists
  if [ -n "$COMBINED_SNAPSHOT_FILE" ]; then
    echo "Appending $DB_NAME to combined backup..."
    cat "$TMP_COMBINED" >> "$COMBINED_SNAPSHOT_FILE"
    echo "" >> "$COMBINED_SNAPSHOT_FILE"  # Add blank line between databases
  fi

  # 5. Compress the export
  echo "Compressing the export for $DB_NAME..."
  gzip -${GZIP_COMPRESSION_LEVEL} "$TMP_COMBINED"

  # 6. Move to final location
  mv "${TMP_COMBINED}.gz" "./${DB_NAME}.gz"

  # 7. Clean up temporary files
  rm -f "$TMP_SCHEMA" "$TMP_DATA" "$TMP_COMBINED"

  echo "✅ Backup completed for $DB_NAME: ./${DB_NAME}.gz"
  return 0
}

# Backup users and grants
snapshot_users_grants() {
  echo "=================================================="
  echo "Backing up users and grants"
  echo "=================================================="

  TMP_USERS="/tmp/users.sql"

  echo "Dumping users and grants..."
  if ! $MYSQLDUMP \
    --skip-ssl \
    --host="${DB_HOSTNAME}" \
    --port="${DB_PORT}" \
    --user="${DB_USER_NAME}" \
    --password="${DB_USER_PASSWORD}" \
    --system=users \
    --default-character-set=${DB_DEFAULT_CHARSET} > "$TMP_USERS" 2>&1; then
    echo "❌ ERROR: Failed to dump users and grants"
    echo "Error output:"
    head -200 "$TMP_USERS" 2>/dev/null || echo "(no error output captured)"
    echo "The database user may lack privileges to dump system users."
    rm -f "$TMP_USERS"
    return 1
  fi
  echo "✅ Dumped users and grants to: $TMP_USERS"

  # Compress the export
  echo "Compressing the users/grants export..."
  gzip -${GZIP_COMPRESSION_LEVEL} "$TMP_USERS"

  # Move to final location
  mv "${TMP_USERS}.gz" "./users.sql.gz"

  echo "✅ Users/grants backup completed: ./users.sql.gz"
  return 0
}

# Get list of databases to backup
get_database_list() {
  # Priority 1: Legacy single database mode (DB_DATABASE)
  if [ -n "${DB_DATABASE}" ]; then
    echo "${DB_DATABASE}"
    return 0
  fi

  # Priority 2: Explicit list (DB_DATABASES)
  if [ -n "${DB_DATABASES}" ]; then
    echo "${DB_DATABASES}" | tr ',' ' '
    return 0
  fi

  # Priority 3: Auto-discovery (DB_SNAPSHOT_ALL_DATABASES)
  if [ "${DB_SNAPSHOT_ALL_DATABASES}" = "true" ] || [ "${DB_SNAPSHOT_ALL_DATABASES}" = "1" ]; then
    echo "Auto-discovering databases..." >&2
    EXCLUDE_LIST="${DB_EXCLUDE_DATABASES}"
    EXCLUDE_PATTERN=$(echo "$EXCLUDE_LIST" | tr ',' '|')

    DBS=$(mysql \
      --skip-ssl \
      --host="${DB_HOSTNAME}" \
      --port="${DB_PORT}" \
      --user="${DB_USER_NAME}" \
      --password="${DB_USER_PASSWORD}" \
      --batch --skip-column-names \
      -e "SHOW DATABASES;" 2>/dev/null | grep -vE "^(${EXCLUDE_PATTERN})$" || true)

    if [ -z "$DBS" ]; then
      echo "❌ ERROR: No databases found or unable to connect to MySQL server" >&2
      exit 1
    fi

    echo "$DBS"
    return 0
  fi

  # No configuration provided
  echo "❌ ERROR: No database configuration provided"
  echo "Please set one of: DB_DATABASE, DB_DATABASES, or DB_SNAPSHOT_ALL_DATABASES=true"
  exit 1
}

# Main execution
echo "=================================================="
echo "MySQL Backup Script"
echo "=================================================="

# Capture start time for metadata
SNAPSHOT_START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SNAPSHOT_START_EPOCH=$(date +%s)

# Get list of databases to backup
DATABASE_LIST=$(get_database_list)
DATABASE_COUNT=$(echo "$DATABASE_LIST" | wc -w)

echo "Databases to backup: $DATABASE_COUNT"
echo "$DATABASE_LIST" | tr ' ' '\n' | sed 's/^/  - /'
echo ""

# Initialize combined backup file if requested
COMBINED_SNAPSHOT_FILE=""
if [ "${DB_SNAPSHOT_COMBINED}" = "true" ] || [ "${DB_SNAPSHOT_COMBINED}" = "1" ]; then
  if [ "${DB_SNAPSHOT_ALL_DATABASES}" = "true" ] || [ "${DB_SNAPSHOT_ALL_DATABASES}" = "1" ]; then
    COMBINED_SNAPSHOT_FILE="/tmp/ALL_DATABASES.sql"
    echo "Combined backup mode enabled - will create ALL_DATABASES.gz"
    # Remove any existing combined file
    rm -f "$COMBINED_SNAPSHOT_FILE"
    echo ""
  else
    echo "⚠️  Warning: DB_SNAPSHOT_COMBINED requires DB_SNAPSHOT_ALL_DATABASES=true. Skipping combined backup."
    echo ""
  fi
fi

# Backup each database
for DB in $DATABASE_LIST; do
  if ! snapshot_single_database "$DB"; then
    echo "❌ Failed to backup database: $DB"
    SNAPSHOTS_FAILED=1
  fi
  echo ""
done

# Create combined backup file if enabled and any databases were backed up
if [ -n "$COMBINED_SNAPSHOT_FILE" ] && [ -f "$COMBINED_SNAPSHOT_FILE" ]; then
  echo "=================================================="
  echo "Creating combined backup file: ALL_DATABASES.gz"
  echo "=================================================="

  # Check if the file has content (more than just blank lines)
  if [ -s "$COMBINED_SNAPSHOT_FILE" ]; then
    echo "Compressing combined backup..."
    gzip -${GZIP_COMPRESSION_LEVEL} "$COMBINED_SNAPSHOT_FILE"
    mv "${COMBINED_SNAPSHOT_FILE}.gz" "./ALL_DATABASES.gz"
    echo "✅ Combined backup created: ./ALL_DATABASES.gz"
  else
    echo "⚠️  Combined backup file is empty, skipping..."
    rm -f "$COMBINED_SNAPSHOT_FILE"
  fi
  echo ""
fi

# Backup users and grants if requested
if [ "${DB_SNAPSHOT_USERS_GRANTS}" = "true" ] || [ "${DB_SNAPSHOT_USERS_GRANTS}" = "1" ]; then
  if ! snapshot_users_grants; then
    echo "❌ Failed to backup users and grants"
    SNAPSHOTS_FAILED=1
  fi
  echo ""
fi

# Generate snapshot metadata
echo "=================================================="
echo "Generating snapshot metadata"
echo "=================================================="
SNAPSHOT_END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SNAPSHOT_END_EPOCH=$(date +%s)
SNAPSHOT_DURATION=$((SNAPSHOT_END_EPOCH - SNAPSHOT_START_EPOCH))

generate_metadata_json "$SNAPSHOT_START_TIME" "$SNAPSHOT_END_TIME" "$SNAPSHOT_DURATION"
echo "✅ Metadata file created: ./snapshot-metadata.json"
echo ""

# Final summary
echo "=================================================="
if [ $SNAPSHOTS_FAILED -eq 0 ]; then
  echo "✅ All database snapshots completed successfully!"
  echo "=================================================="
  exit 0
else
  echo "⚠️  Some database snapshots failed. Please check the log above."
  echo "=================================================="
  exit 1
fi
