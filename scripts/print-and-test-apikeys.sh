#!/usr/bin/env bash
set -euo pipefail

SONARR_CFG="/opt/mediaserver/sonarr/config.xml"
RADARR_CFG="/opt/mediaserver/radarr/config.xml"

SONARR_URL="${SONARR_URL:-http://127.0.0.1:8989}"
RADARR_URL="${RADARR_URL:-http://127.0.0.1:7878}"

extract_key() {
  # minimal XML key extractor without xmlstarlet
  # usage: extract_key /path/to/config.xml
  local file="$1"
  [ -f "$file" ] || { echo ""; return; }
  # pull first <ApiKey>…</ApiKey> value
  awk 'BEGIN{RS="</ApiKey>";FS="<ApiKey>"} NF>1{print $2; exit}' "$file" | tr -d ' \t\r\n'
}

http_status() {
  # curl status code only
  curl -s -o /dev/null -w "%{http_code}" "$1"
}

mask_key() {
  local key="$1"

  if [ -z "$key" ]; then
    echo ""
    return
  fi

  if [ "${SHOW_FULL_KEYS:-}" = "1" ]; then
    echo "$key"
    return
  fi

  local len=${#key}
  if [ "$len" -le 8 ]; then
    printf '%*s' "$len" '' | tr ' ' '*'
    return
  fi

  local prefix=${key:0:4}
  local suffix=${key: -4}
  local masked_len=$((len - 8))

  printf '%s' "$prefix"
  printf '%*s' "$masked_len" '' | tr ' ' '*'
  printf '%s' "$suffix"
}

echo "==> Reading API keys from config.xml…"
SONARR_KEY="$(extract_key "$SONARR_CFG")"
RADARR_KEY="$(extract_key "$RADARR_CFG")"

if [ -n "$SONARR_KEY" ]; then
  echo "Sonarr API key:  $(mask_key "$SONARR_KEY")"
else
  echo "Sonarr API key:  (NOT FOUND)"
fi

if [ -n "$RADARR_KEY" ]; then
  echo "Radarr API key:  $(mask_key "$RADARR_KEY")"
else
  echo "Radarr API key:  (NOT FOUND)"
fi

if [ "${SHOW_FULL_KEYS:-}" != "1" ]; then
  echo
  echo "    (Set SHOW_FULL_KEYS=1 to print unredacted keys.)"
fi

echo
echo "==> Testing API keys against running services…"
if [ -n "$SONARR_KEY" ]; then
  S_CODE="$(http_status "${SONARR_URL}/api/v3/system/status?apikey=${SONARR_KEY}")"
  echo "Sonarr status: ${S_CODE}  (${SONARR_URL}/api/v3/system/status)"
else
  echo "Sonarr status: no key present to test"
fi

if [ -n "$RADARR_KEY" ]; then
  R_CODE="$(http_status "${RADARR_URL}/api/v3/system/status?apikey=${RADARR_KEY}")"
  echo "Radarr status: ${R_CODE}  (${RADARR_URL}/api/v3/system/status)"
else
  echo "Radarr status: no key present to test"
fi

echo
echo "==> If codes are 200, your keys are valid and services are reachable."
echo "    If not, confirm containers are up and ports reachable, or check reverse proxy settings."
