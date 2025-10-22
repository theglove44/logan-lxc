#!/usr/bin/env bash
set -euo pipefail

# Ensure we can resolve the directory even if invoked via symlink
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
  DIR=$(cd -P "$(dirname "$SOURCE")" && pwd)
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR=$(cd -P "$(dirname "$SOURCE")" && pwd)

# shellcheck source=scripts/lib/bootstrap_common.sh
source "$SCRIPT_DIR/lib/bootstrap_common.sh"
bootstrap::set_curl_defaults 8 4

# ======= CONFIG (matches compose.yml defaults; override via env if needed) =======
SONARR_PUBLIC="${SONARR_PUBLIC:-http://127.0.0.1:8989}"
RADARR_PUBLIC="${RADARR_PUBLIC:-http://127.0.0.1:7878}"
SAB_PUBLIC="${SAB_PUBLIC:-http://127.0.0.1:8080}"
PROWLARR_PUBLIC="${PROWLARR_PUBLIC:-http://127.0.0.1:9696}"

SONARR_INTERNAL="${SONARR_INTERNAL:-http://sonarr:8989}"
RADARR_INTERNAL="${RADARR_INTERNAL:-http://radarr:7878}"
SAB_INTERNAL_HOST="${SAB_INTERNAL_HOST:-sabnzbd}"
SAB_INTERNAL_PORT="${SAB_INTERNAL_PORT:-8080}"

TV_ROOT="${TV_ROOT:-/tv}"
MOVIES_ROOT="${MOVIES_ROOT:-/movies}"
SAB_COMPLETE="${SAB_COMPLETE:-/downloads}"
SAB_INCOMPLETE="${SAB_INCOMPLETE:-/incomplete-downloads}"
SAB_TV_CATEGORY="${SAB_TV_CATEGORY:-tv}"
SAB_MOVIES_CATEGORY="${SAB_MOVIES_CATEGORY:-movies}"

SONARR_CLIENT_NAME="${SONARR_CLIENT_NAME:-sabnzbd}"
RADARR_CLIENT_NAME="${RADARR_CLIENT_NAME:-sabnzbd}"

# ======= Pre-flight =======
bootstrap::need_bin curl
bootstrap::need_bin jq
bootstrap::wait_http "${SAB_PUBLIC}/api?mode=version" "SABnzbd"
bootstrap::wait_http "${SONARR_PUBLIC}/" "Sonarr"
bootstrap::wait_http "${RADARR_PUBLIC}/" "Radarr"
bootstrap::wait_http "${PROWLARR_PUBLIC}/" "Prowlarr"

echo
echo "Enter API keys (find them in each app's UI):"
bootstrap::prompt_secret SAB_API_KEY      "SABnzbd API key"
bootstrap::prompt_secret SONARR_API_KEY   "Sonarr API key"
bootstrap::prompt_secret RADARR_API_KEY   "Radarr API key"
bootstrap::prompt_secret PROWLARR_API_KEY "Prowlarr API key"

HDR_SONARR="X-Api-Key: ${SONARR_API_KEY}"
HDR_RADARR="X-Api-Key: ${RADARR_API_KEY}"
HDR_PROWLARR="X-Api-Key: ${PROWLARR_API_KEY}"

# ======= SABnzbd: folders & categories =======
echo
echo "Configuring SABnzbd folders and categories ..."
bootstrap::curl_get_params "${SAB_PUBLIC}/api" \
  --data-urlencode "apikey=${SAB_API_KEY}" \
  --data-urlencode "mode=set_config" \
  --data-urlencode "name=download_dir" \
  --data-urlencode "value=${SAB_COMPLETE}" >/dev/null

bootstrap::curl_get_params "${SAB_PUBLIC}/api" \
  --data-urlencode "apikey=${SAB_API_KEY}" \
  --data-urlencode "mode=set_config" \
  --data-urlencode "name=complete_dir" \
  --data-urlencode "value=${SAB_COMPLETE}" >/dev/null

bootstrap::curl_get_params "${SAB_PUBLIC}/api" \
  --data-urlencode "apikey=${SAB_API_KEY}" \
  --data-urlencode "mode=set_config" \
  --data-urlencode "name=script_dir" \
  --data-urlencode "value=" >/dev/null

bootstrap::curl_get_params "${SAB_PUBLIC}/api" \
  --data-urlencode "apikey=${SAB_API_KEY}" \
  --data-urlencode "mode=set_config" \
  --data-urlencode "name=dirscan_dir" \
  --data-urlencode "value=${SAB_COMPLETE}" >/dev/null

bootstrap::curl_get_params "${SAB_PUBLIC}/api" \
  --data-urlencode "apikey=${SAB_API_KEY}" \
  --data-urlencode "mode=set_config" \
  --data-urlencode "name=incomplete_dir" \
  --data-urlencode "value=${SAB_INCOMPLETE}" >/dev/null

sab_add_cat() {
  local name="$1" dir="$2"
  bootstrap::curl_get_params "${SAB_PUBLIC}/api" \
    --data-urlencode "apikey=${SAB_API_KEY}" \
    --data-urlencode "mode=add_category" \
    --data-urlencode "name=${name}" \
    --data-urlencode "pp=Default" \
    --data-urlencode "script=" \
    --data-urlencode "dir=${dir}" \
    --data-urlencode "priority=0" >/dev/null
}
sab_add_cat "${SAB_TV_CATEGORY}" "${SAB_COMPLETE}/${SAB_TV_CATEGORY}"
sab_add_cat "${SAB_MOVIES_CATEGORY}" "${SAB_COMPLETE}/${SAB_MOVIES_CATEGORY}"
echo "SABnzbd configured."

# ======= Sonarr: root folder (/tv) & SAB client =======
echo
echo "Configuring Sonarr root folder and SAB download client ..."
SONARR_BASE="$SONARR_PUBLIC"
if sys_json=$(bootstrap::curl_get "$HDR_SONARR" "${SONARR_PUBLIC}/api/v3/system/status" 2>/dev/null); then
  if base_url=$(jq -r '.urlBase // ""' <<<"$sys_json" 2>/dev/null); then
    if [ -n "$base_url" ] && [ "$base_url" != "/" ]; then
      SONARR_BASE="${SONARR_PUBLIC%/}/${base_url#/}"
      echo "Detected Sonarr URL Base: $base_url → using $SONARR_BASE"
    fi
  fi
fi

SONARR_ROOTS=$(bootstrap::curl_get "$HDR_SONARR" "${SONARR_BASE}/api/v3/rootFolder")
if ! jq -e --arg p1 "$TV_ROOT" --arg p2 "${TV_ROOT%/}/" '.[] | select(.path==$p1 or .path==$p2)' >/dev/null <<<"$SONARR_ROOTS"; then
  bootstrap::curl_post "$HDR_SONARR" "{\"path\":\"${TV_ROOT}\",\"accessible\":true}" "${SONARR_BASE}/api/v3/rootFolder" >/dev/null
fi

SONARR_CLIENTS=$(bootstrap::curl_get "$HDR_SONARR" "${SONARR_BASE}/api/v3/downloadclient")
if ! jq -e --arg name "$SONARR_CLIENT_NAME" '.[] | select(.name==$name)' >/dev/null <<<"$SONARR_CLIENTS"; then
  bootstrap::curl_post "$HDR_SONARR" "$(cat <<JSON
{
  "enable": true,
  "name": "${SONARR_CLIENT_NAME}",
  "protocol": "usenet",
  "implementation": "Sabnzbd",
  "configContract": "SabnzbdSettings",
  "fields": [
    {"name":"host", "value":"${SAB_INTERNAL_HOST}"},
    {"name":"port", "value":${SAB_INTERNAL_PORT}},
    {"name":"apiKey", "value":"${SAB_API_KEY}"},
    {"name":"username", "value":""},
    {"name":"password", "value":""},
    {"name":"tvCategory", "value":"${SAB_TV_CATEGORY}"},
    {"name":"useSsl", "value":false},
    {"name":"urlBase", "value":""},
    {"name":"removeCompletedDownloads", "value":true},
    {"name":"recentTvPriority", "value":0},
    {"name":"olderTvPriority", "value":0}
  ]
}
JSON
)" "${SONARR_BASE}/api/v3/downloadclient" >/dev/null
fi

bootstrap::curl_put "$HDR_SONARR" '{"completedDownloadHandling":{"enable":true,"redownloadFailed":true}}' \
  "${SONARR_BASE}/api/v3/config/downloadclient" >/dev/null
echo "Sonarr configured."

# ======= Radarr: root folder (/movies) & SAB client =======
echo
echo "Configuring Radarr root folder and SAB download client ..."
RADARR_ROOTS=$(bootstrap::curl_get "$HDR_RADARR" "${RADARR_PUBLIC}/api/v3/rootFolder")
if ! jq -e --arg p1 "$MOVIES_ROOT" --arg p2 "${MOVIES_ROOT%/}/" '.[] | select(.path==$p1 or .path==$p2)' >/dev/null <<<"$RADARR_ROOTS"; then
  bootstrap::curl_post "$HDR_RADARR" "{\"path\":\"${MOVIES_ROOT}\",\"accessible\":true}" "${RADARR_PUBLIC}/api/v3/rootFolder" >/dev/null
fi

RADARR_CLIENTS=$(bootstrap::curl_get "$HDR_RADARR" "${RADARR_PUBLIC}/api/v3/downloadclient")
if ! jq -e --arg name "$RADARR_CLIENT_NAME" '.[] | select(.name==$name)' >/dev/null <<<"$RADARR_CLIENTS"; then
  bootstrap::curl_post "$HDR_RADARR" "$(cat <<JSON
{
  "enable": true,
  "name": "${RADARR_CLIENT_NAME}",
  "protocol": "usenet",
  "implementation": "Sabnzbd",
  "configContract": "SabnzbdSettings",
  "fields": [
    {"name":"host", "value":"${SAB_INTERNAL_HOST}"},
    {"name":"port", "value":${SAB_INTERNAL_PORT}},
    {"name":"apiKey", "value":"${SAB_API_KEY}"},
    {"name":"username", "value":""},
    {"name":"password", "value":""},
    {"name":"category", "value":"${SAB_MOVIES_CATEGORY}"},
    {"name":"useSsl", "value":false},
    {"name":"urlBase", "value":""},
    {"name":"removeCompletedDownloads", "value":true}
  ]
}
JSON
)" "${RADARR_PUBLIC}/api/v3/downloadclient" >/dev/null
fi

bootstrap::curl_put "$HDR_RADARR" '{"completedDownloadHandling":{"enable":true,"redownloadFailed":true}}' \
  "${RADARR_PUBLIC}/api/v3/config/downloadclient" >/dev/null
echo "Radarr configured."

# ======= Prowlarr: register Sonarr & Radarr (internal URLs) =======
echo
echo "Registering Sonarr/Radarr inside Prowlarr ..."
APPS_JSON=$(bootstrap::curl_get "$HDR_PROWLARR" "${PROWLARR_PUBLIC}/api/v1/applications")
if ! jq -e '.[] | select(.name=="Sonarr")' >/dev/null <<<"$APPS_JSON"; then
  bootstrap::curl_post "$HDR_PROWLARR" "$(cat <<JSON
{
  "name": "Sonarr",
  "implementation": "Sonarr",
  "configContract": "SonarrSettings",
  "syncLevel": "fullSync",
  "fields": [
    {"name":"apiKey","value":"${SONARR_API_KEY}"},
    {"name":"baseUrl","value":"${SONARR_INTERNAL}"},
    {"name":"shouldSyncCategories","value":true},
    {"name":"tags","value":[]}
  ]
}
JSON
)" "${PROWLARR_PUBLIC}/api/v1/applications" >/dev/null
  APPS_JSON=""
fi

if [ -z "$APPS_JSON" ]; then
  APPS_JSON=$(bootstrap::curl_get "$HDR_PROWLARR" "${PROWLARR_PUBLIC}/api/v1/applications")
fi
if ! jq -e '.[] | select(.name=="Radarr")' >/dev/null <<<"$APPS_JSON"; then
  bootstrap::curl_post "$HDR_PROWLARR" "$(cat <<JSON
{
  "name": "Radarr",
  "implementation": "Radarr",
  "configContract": "RadarrSettings",
  "syncLevel": "fullSync",
  "fields": [
    {"name":"apiKey","value":"${RADARR_API_KEY}"},
    {"name":"baseUrl","value":"${RADARR_INTERNAL}"},
    {"name":"shouldSyncCategories","value":true},
    {"name":"tags","value":[]}
  ]
}
JSON
)" "${PROWLARR_PUBLIC}/api/v1/applications" >/dev/null
fi

echo
echo "All set! ✅  SAB categories, Sonarr/Radarr roots + SAB clients, and Prowlarr apps configured."
echo "Next:"
echo "  • Add your indexers in Prowlarr — they'll sync to Sonarr/Radarr."
echo "  • In Bazarr UI, connect to Sonarr/Radarr via ${SONARR_INTERNAL} & ${RADARR_INTERNAL}."
echo "  • In Jellyseerr UI, connect Jellyfin + Sonarr/Radarr."
