#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ENV_FILE:-${REPO_ROOT}/.env}"

if [ -f "$ENV_FILE" ]; then
  # shellcheck source=/dev/null
  set -a
  source "$ENV_FILE"
  set +a
fi

RECOVERY_SOURCE_HOST="${RECOVERY_SOURCE_HOST:-${1:-}}"
if [ -z "$RECOVERY_SOURCE_HOST" ]; then
  echo "Set RECOVERY_SOURCE_HOST or pass the source host as the first argument." >&2
  exit 1
fi

OLD_HOST="$RECOVERY_SOURCE_HOST"
OLD_PORT="${RECOVERY_SOURCE_PORT:-2053}"
OLD_PATH="${RECOVERY_SOURCE_PATH:-/home/christof21/mediaserver/appdata/radarr}"
NEW_CFG="/opt/mediaserver/radarr"
RESTORE_STAGE="/opt/mediaserver/radarr_restore"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

say() { printf "\n==> %s\n" "$*"; }

say "Stopping Radarr container (if running)…"
docker stop radarr >/dev/null 2>&1 || true

say "Ensuring restore staging dir exists…"
mkdir -p "$RESTORE_STAGE"

say "Pulling OLD config from ${OLD_HOST}:${OLD_PORT}${OLD_PATH} -> $RESTORE_STAGE"
rsync -avz -e "ssh -p ${OLD_PORT}" \
  "christof21@${OLD_HOST}:${OLD_PATH}/" \
  "${RESTORE_STAGE}/"

say "Top-level of staged restore:"
ls -lah "${RESTORE_STAGE}" | sed -n '1,200p'

# If there's an inner 'config' dir, use that as the actual config root (LinuxServer style)
CFG_ROOT="$RESTORE_STAGE"
if [ -d "${RESTORE_STAGE}/config" ]; then
  say "Detected nested 'config/' directory – using that as the config root."
  CFG_ROOT="${RESTORE_STAGE}/config"
fi

say "Listing config root: ${CFG_ROOT}"
ls -lah "${CFG_ROOT}" | sed -n '1,200p'

R_DB="${CFG_ROOT}/radarr.db"
N_DB="${CFG_ROOT}/nzbdrone.db"   # rare/legacy, but we handle it just in case

has_r_db="no"; [ -f "$R_DB" ] && has_r_db="yes"
has_n_db="no"; [ -f "$N_DB" ] && has_n_db="yes"

say "DB presence in config root: radarr.db=${has_r_db}, nzbdrone.db=${has_n_db}"
if [ "$has_r_db" = "no" ] && [ "$has_n_db" = "no" ]; then
  say "No DBs found. Checking for built-in backups…"
  if [ -d "${CFG_ROOT}/Backups/scheduled" ]; then
    say "Backups found. Restoring newest backup ZIP."
    LATEST=$(ls -t "${CFG_ROOT}/Backups/scheduled"/*.zip 2>/dev/null | head -n1 || true)
    if [ -n "${LATEST}" ]; then
      say "Using backup: ${LATEST}"
      tmpdir="$(mktemp -d)"
      unzip -o "${LATEST}" -d "${tmpdir}"
      # Expect radarr.db and config.xml
      [ -f "${tmpdir}/radarr.db" ] || { echo "Backup missing radarr.db"; exit 1; }
      cp -f "${tmpdir}/radarr.db" "${CFG_ROOT}/"
      [ -f "${tmpdir}/config.xml" ] && cp -f "${tmpdir}/config.xml" "${CFG_ROOT}/" || true
      rm -rf "${tmpdir}"
      has_r_db="yes"
    else
      echo "ERROR: No DBs and no backup ZIPs found. Aborting to avoid blank startup."
      exit 1
    fi
  else
    echo "ERROR: No DBs found and no Backups/scheduled folder present. Aborting."
    exit 1
  fi
fi

# If both legacy and current DB exist and a tiny radarr.db is present, prefer legacy migration
if [ "$has_r_db" = "yes" ] && [ "$has_n_db" = "yes" ]; then
  R_SIZE=$(stat -c%s "$R_DB" || echo 0)
  say "radarr.db size: ${R_SIZE} bytes"
  if [ "$R_SIZE" -lt 200000 ]; then
    say "radarr.db looks tiny; removing it so Radarr can migrate from nzbdrone.db."
    rm -f "$R_DB"
    has_r_db="no"
  fi
fi

say "Backing up current NEW config (if any)…"
if [ -d "$NEW_CFG" ]; then
  BK="${NEW_CFG}.$(date +%Y%m%d-%H%M%S).bak"
  cp -a "$NEW_CFG" "$BK"
  say "Backup saved to: $BK"
fi

say "Replacing NEW config with CONTENTS of ${CFG_ROOT}…"
mkdir -p "$NEW_CFG"
rsync -av --delete "${CFG_ROOT}/" "${NEW_CFG}/"

say "Fixing ownership to ${PUID}:${PGID}…"
chown -R "${PUID}:${PGID}" "${NEW_CFG}"

say "Bringing Radarr up (compose)…"
docker compose down radarr >/dev/null 2>&1 || true
docker compose up -d radarr

say "Listing /config inside container (should show *.db, Backups, MediaCover, config.xml)…"
sleep 3
docker exec radarr sh -lc 'ls -lah /config | sed -n "1,200p"'
