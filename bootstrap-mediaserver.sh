#!/usr/bin/env bash
set -euo pipefail

# ======= CONFIG (match compose.yml) =======
SONARR_PUBLIC="http://127.0.0.1:8989"
RADARR_PUBLIC="http://127.0.0.1:7878"
SAB_PUBLIC="http://127.0.0.1:8080"
PROWLARR_PUBLIC="http://127.0.0.1:9696"

SONARR_INTERNAL="http://sonarr:8989"
RADARR_INTERNAL="http://radarr:7878"
SAB_INTERNAL_HOST="sabnzbd"
SAB_INTERNAL_PORT=8080

TV_ROOT="/tv"
MOVIES_ROOT="/movies"
SAB_COMPLETE="/downloads"
SAB_INCOMPLETE="/incomplete-downloads"

CURL_COMMON=(-sS --fail-with-body --max-time 8 --connect-timeout 4)

# ======= Helpers =======
wait_http() {
  local url="$1" name="$2" max="${3:-90}"
  echo "Waiting for $name at $url ..."
  local code=""
  for _ in $(seq 1 "$max"); do
    code="$(curl -s -o /dev/null -w "%{http_code}" "$url" || true)"
    if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ] || [ "$code" = "401" ]; then
      echo "OK: $name is up (HTTP $code)"
      return 0
    fi
    sleep 2
  done
  echo "ERROR: $name not responding at $url (last HTTP code: $code)" >&2
  exit 1
}

prompt_secret() {
  local var="$1" prompt="$2"
  if [ -z "${!var:-}" ]; then
    read -r -p "$prompt: " "$var"
    export "$var"
  fi
}

need_bin() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }

do_get() { curl "${CURL_COMMON[@]}" -H "$1" "$2"; }
do_post() { curl "${CURL_COMMON[@]}" -X POST -H "$1" -H "Content-Type: application/json" -d "$2" "$3"; }
do_put() { curl "${CURL_COMMON[@]}" -X PUT  -H "$1" -H "Content-Type: application/json" -d "$2" "$3"; }
do_get_params() { curl "${CURL_COMMON[@]}" --get "$@"; }

# ======= Pre-flight =======
need_bin curl; need_bin jq
wait_http "${SAB_PUBLIC}/api?mode=version" "SABnzbd"
wait_http "${SONARR_PUBLIC}/" "Sonarr"
wait_http "${RADARR_PUBLIC}/" "Radarr"
wait_http "${PROWLARR_PUBLIC}/" "Prowlarr"

echo
echo "Enter API keys (find them in each app's UI):"
prompt_secret SAB_API_KEY        "SABnzbd API key"
prompt_secret SONARR_API_KEY     "Sonarr API key"
prompt_secret RADARR_API_KEY     "Radarr API key"
prompt_secret PROWLARR_API_KEY   "Prowlarr API key"

# ======= SABnzbd: folders & categories =======
echo
echo "Configuring SABnzbd folders and categories ..."
do_get_params "${SAB_PUBLIC}/api" \
  --data-urlencode "apikey=${SAB_API_KEY}" \
  --data-urlencode "mode=set_config" \
  --data-urlencode "name=download_dir" \
  --data-urlencode "value=${SAB_COMPLETE}" >/dev/null

do_get_params "${SAB_PUBLIC}/api" \
  --data-urlencode "apikey=${SAB_API_KEY}" \
  --data-urlencode "mode=set_config" \
  --data-urlencode "name=complete_dir" \
  --data-urlencode "value=${SAB_COMPLETE}" >/dev/null

add_cat() {
  local name="$1" dir="$2"
  do_get_params "${SAB_PUBLIC}/api" \
    --data-urlencode "apikey=${SAB_API_KEY}" \
    --data-urlencode "mode=add_category" \
    --data-urlencode "name=${name}" \
    --data-urlencode "pp=Default" \
    --data-urlencode "script=" \
    --data-urlencode "dir=${dir}" \
    --data-urlencode "priority=0" >/dev/null
}
add_cat "tv"     "${SAB_COMPLETE}/tv"
add_cat "movies" "${SAB_COMPLETE}/movies"
echo "SABnzbd configured."

# ======= Sonarr: root folder (/tv) & SAB client (tvCategory!) =======
echo
echo "Configuring Sonarr root folder and SAB download client ..."
HDR_SONARR="X-Api-Key: ${SONARR_API_KEY}"

# Root folder
if ! do_get "$HDR_SONARR" "${SONARR_PUBLIC}/api/v3/rootFolder" | jq -e ".[] | select(.path==\"${TV_ROOT}\")" >/dev/null; then
  do_post "$HDR_SONARR" "{\"path\":\"${TV_ROOT}\",\"accessible\":true}" "${SONARR_PUBLIC}/api/v3/rootFolder" >/dev/null
fi

# SAB client (note tvCategory)
SONARR_CLIENT_NAME="sabnzbd"
if ! do_get "$HDR_SONARR" "${SONARR_PUBLIC}/api/v3/downloadclient" | jq -e ".[] | select(.name==\"${SONARR_CLIENT_NAME}\")" >/dev/null; then
  do_post "$HDR_SONARR" "$(cat <<JSON
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
    {"name":"tvCategory", "value":"tv"},
    {"name":"useSsl", "value":false},
    {"name":"urlBase", "value":""},
    {"name":"removeCompletedDownloads", "value":true},
    {"name":"recentTvPriority", "value":0},
    {"name":"olderTvPriority", "value":0}
  ]
}
JSON
)" "${SONARR_PUBLIC}/api/v3/downloadclient" >/dev/null
fi

# Enable Completed Download Handling
do_put "$HDR_SONARR" '{"completedDownloadHandling":{"enable":true,"redownloadFailed":true}}' \
  "${SONARR_PUBLIC}/api/v3/config/downloadclient" >/dev/null

echo "Sonarr configured."

# ======= Radarr: root folder (/movies) & SAB client =======
echo
echo "Configuring Radarr root folder and SAB download client ..."
HDR_RADARR="X-Api-Key: ${RADARR_API_KEY}"

if ! do_get "$HDR_RADARR" "${RADARR_PUBLIC}/api/v3/rootFolder" | jq -e ".[] | select(.path==\"${MOVIES_ROOT}\")" >/dev/null; then
  do_post "$HDR_RADARR" "{\"path\":\"${MOVIES_ROOT}\",\"accessible\":true}" "${RADARR_PUBLIC}/api/v3/rootFolder" >/dev/null
fi

RADARR_CLIENT_NAME="sabnzbd"
if ! do_get "$HDR_RADARR" "${RADARR_PUBLIC}/api/v3/downloadclient" | jq -e ".[] | select(.name==\"${RADARR_CLIENT_NAME}\")" >/dev/null; then
  do_post "$HDR_RADARR" "$(cat <<JSON
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
    {"name":"category", "value":"movies"},
    {"name":"useSsl", "value":false},
    {"name":"urlBase", "value":""},
    {"name":"removeCompletedDownloads", "value":true}
  ]
}
JSON
)" "${RADARR_PUBLIC}/api/v3/downloadclient" >/dev/null
fi

do_put "$HDR_RADARR" '{"completedDownloadHandling":{"enable":true,"redownloadFailed":true}}' \
  "${RADARR_PUBLIC}/api/v3/config/downloadclient" >/dev/null

echo "Radarr configured."

# ======= Prowlarr: register Sonarr & Radarr (internal URLs) =======
echo
echo "Registering Sonarr/Radarr inside Prowlarr ..."
HDR_PROWLARR="X-Api-Key: ${PROWLARR_API_KEY}"

if ! do_get "$HDR_PROWLARR" "${PROWLARR_PUBLIC}/api/v1/applications" | jq -e '.[] | select(.name=="Sonarr")' >/dev/null; then
  do_post "$HDR_PROWLARR" "$(cat <<JSON
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
fi

if ! do_get "$HDR_PROWLARR" "${PROWLARR_PUBLIC}/api/v1/applications" | jq -e '.[] | select(.name=="Radarr")' >/dev/null; then
  do_post "$HDR_PROWLARR" "$(cat <<JSON
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
