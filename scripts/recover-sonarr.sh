#!/usr/bin/env bash
set -euo pipefail

OLD_HOST="10.0.0.179"
OLD_PORT="2053"
OLD_PATH="/home/christof21/mediaserver/appdata/sonarr"
NEW_CFG="/opt/mediaserver/sonarr"
RESTORE_STAGE="/opt/mediaserver/sonarr_restore"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

say() { printf "\n==> %s\n" "$*"; }

say "Stopping Sonarr container (if running)…"
docker stop sonarr >/dev/null 2>&1 || true

say "Ensuring restore staging dir exists…"
mkdir -p "$RESTORE_STAGE"

say "Pulling OLD config from ${OLD_HOST}:${OLD_PORT}${OLD_PATH} -> $RESTORE_STAGE"
rsync -avz -e "ssh -p ${OLD_PORT}" \
  "christof21@${OLD_HOST}:${OLD_PATH}/" \
  "${RESTORE_STAGE}/"

say "Top-level of staged restore:"
ls -lah "${RESTORE_STAGE}" | sed -n '1,200p'

# If there's an inner 'config' dir, use that as the actual config root
CFG_ROOT="$RESTORE_STAGE"
if [ -d "${RESTORE_STAGE}/config" ]; then
  say "Detected nested 'config/' directory – using that as the config root."
  CFG_ROOT="${RESTORE_STAGE}/config"
fi

say "Listing config root: ${CFG_ROOT}"
ls -lah "${CFG_ROOT}" | sed -n '1,200p'

S_DB="${CFG_ROOT}/sonarr.db"
N_DB="${CFG_ROOT}/nzbdrone.db"

has_s_db="no"; [ -f "$S_DB" ] && has_s_db="yes"
has_n_db="no"; [ -f "$N_DB" ] && has_n_db="yes"

say "DB presence in config root: sonarr.db=${has_s_db}, nzbdrone.db=${has_n_db}"
if [ "$has_s_db" = "no" ] && [ "$has_n_db" = "no" ]; then
  say "Could not find DB files. Checking for built-in backups…"
  if [ -d "${CFG_ROOT}/Backups/scheduled" ]; then
    say "Backups found. Will restore the newest backup ZIP."
    LATEST=$(ls -t "${CFG_ROOT}/Backups/scheduled"/*.zip 2>/dev/null | head -n1 || true)
    if [ -n "${LATEST}" ]; then
      say "Using backup: ${LATEST}"
      tmpdir="$(mktemp -d)"
      unzip -o "${LATEST}" -d "${tmpdir}"
      # Expect sonarr.db and config.xml inside
      [ -f "${tmpdir}/sonarr.db" ] || { echo "Backup missing sonarr.db"; exit 1; }
      cp -f "${tmpdir}/sonarr.db" "${CFG_ROOT}/"
      [ -f "${tmpdir}/config.xml" ] && cp -f "${tmpdir}/config.xml" "${CFG_ROOT}/" || true
      rm -rf "${tmpdir}"
      has_s_db="yes"
    else
      echo "ERROR: No DBs and no backup ZIPs found. Aborting to avoid blank startup."
      exit 1
    fi
  else
    echo "ERROR: No DBs found and no Backups/scheduled folder present. Aborting."
    exit 1
  fi
fi

# Handle migration from nzbdrone.db (v3 -> v4)
if [ "$has_s_db" = "yes" ]; then
  S_SIZE=$(stat -c%s "$S_DB" || echo 0)
  say "sonarr.db size: ${S_SIZE} bytes"
  if [ "$S_SIZE" -lt 200000 ] && [ "$has_n_db" = "yes" ]; then
    say "sonarr.db looks tiny; removing it so Sonarr can migrate from nzbdrone.db."
    rm -f "$S_DB"
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

say "Bringing Sonarr up (compose)…"
docker compose down sonarr >/dev/null 2>&1 || true
docker compose up -d sonarr

say "Listing /config inside container (should show *.db, Backups, mediaCover, config.xml)…"
sleep 3
docker exec sonarr sh -lc 'ls -lah /config | sed -n "1,200p"'
