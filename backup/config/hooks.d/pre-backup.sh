#!/usr/bin/env sh
set -eu

SNAP_ROOT="/run/sqlite-snapshots"
SRC_ROOT="/backup/mediaserver"

echo "[pre-backup] Creating SQLite snapshots under $SNAP_ROOT"

# Ensure sqlite3 exists
if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "[pre-backup] WARNING: sqlite3 not found in image; skipping DB snapshots."
  exit 0
fi

# fresh snapshot dir
rm -rf "$SNAP_ROOT"
mkdir -p "$SNAP_ROOT"

# Find DBs: *.db or *.sqlite within your config tree
# (matches sonarr.db, radarr.db, prowlarr.db, logs.db, bazarr dbs, jellyfin dbs, jellyseerr dbs, etc.)
find "$SRC_ROOT" -type f \( -name "*.db" -o -name "*.sqlite" \) | while read -r DB; do
  # Compute relative path under SNAP_ROOT
  REL="${DB#${SRC_ROOT}/}"
  OUT="$SNAP_ROOT/$REL"

  mkdir -p "$(dirname "$OUT")"
  echo "  - snapshot: $REL"
  # Use SQLite online backup API for a consistent copy
  sqlite3 "$DB" ".backup '$OUT'" || {
    echo "    ! snapshot failed for $DB, continuing..."
    continue
  }
done

echo "[pre-backup] SQLite snapshots complete."
