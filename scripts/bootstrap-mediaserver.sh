#!/usr/bin/env bash
set -euo pipefail

# ======= Resolve repo root & env =======
SOURCE=${BASH_SOURCE[0]}
while [ -L "$SOURCE" ]; do
  DIR=$(cd -P "$(dirname "$SOURCE")" && pwd)
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR=$(cd -P "$(dirname "$SOURCE")" && pwd)
ROOT_DIR=$(cd -P "$SCRIPT_DIR/.." && pwd)

ENV_FILE="$ROOT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

: "${HOST_LAN:?HOST_LAN must be set (edit .env)}"
if [ "$HOST_LAN" = "CHANGE_ME" ]; then
  echo "Please set HOST_LAN in .env to the LAN IP or hostname of this host." >&2
  exit 1
fi

# ======= CONFIG (match compose.yml) =======
# Public (host) URLs for readiness checks:
SONARR_PUBLIC="http://127.0.0.1:8989"
RADARR_PUBLIC="http://127.0.0.1:7878"
PROWLARR_PUBLIC="http://127.0.0.1:9696"

# Sonarr/Radarr -> SAB: use the host's LAN IP to avoid SAB host-whitelist 403
SAB_HOST="$HOST_LAN"
SAB_PORT=8080

# Internal URLs for Prowlarr apps (container-to-container is fine here):
SONARR_INTERNAL="http://sonarr:8989"
RADARR_INTERNAL="http://radarr:7878"

# Container-internal root folders (per compose mounts):
TV_ROOT="/tv"
MOVIES_ROOT="/movies"

CURL_COMMON=(-sS --fail-with-body --max-time 12 --connect-timeout 4)

# ======= Helpers =======
need_bin() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }

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

api_call() {
  local method="$1" url="$2" header_json="${3:-}" body_json="${4:-}"
  local args=("${CURL_COMMON[@]}" "-w" "\n__HTTP_CODE__:%{http_code}\n")
  if [ -n "$header_json" ]; then
    while IFS="=" read -r k v; do
      [ -z "$k" ] && continue
      args+=(-H "$k: ${v}")
    done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' <<<"$header_json")
  fi
  case "$method" in
    GET)  args+=("$url");;
    POST) args+=(-X POST "$url" -H "Content-Type: application/json" --data-binary "$body_json");;
    PUT)  args+=(-X PUT  "$url" -H "Content-Type: application/json" --data-binary "$body_json");;
    *) echo "Unsupported method $method" >&2; exit 1;;
  esac
  local resp code
  resp="$(curl "${args[@]}" || true)"
  code="$(sed -n 's/^__HTTP_CODE__://p' <<<"$resp" | tail -n1)"
  resp="$(sed '/^__HTTP_CODE__:/d' <<<"$resp")"
  if [[ "$code" =~ ^2 ]]; then
    printf "%s" "$resp"
    return 0
  fi
  echo "HTTP $code from $method $url" >&2
  [ -n "$resp" ] && echo "Response body:" >&2 && echo "$resp" >&2
  return 1
}

# ======= Pre-flight =======
need_bin curl; need_bin jq
wait_http "${SONARR_PUBLIC}/" "Sonarr"
wait_http "${RADARR_PUBLIC}/" "Radarr"
wait_http "${PROWLARR_PUBLIC}/" "Prowlarr"

echo
echo "Enter API keys (from each UI Settings → General):"
read -r -p "SABnzbd API key: " SAB_API_KEY
read -r -p "Sonarr  API key: " SONARR_API_KEY
read -r -p "Radarr  API key: " RADARR_API_KEY
read -r -p "Prowlarr API key: " PROWLARR_API_KEY

HDR_SONARR="$(jq -nc --arg k "$SONARR_API_KEY" '{ "X-Api-Key": $k }')"
HDR_RADARR="$(jq -nc --arg k "$RADARR_API_KEY" '{ "X-Api-Key": $k }')"
HDR_PROWLARR="$(jq -nc --arg k "$PROWLARR_API_KEY" '{ "X-Api-Key": $k }')"

# ======= Sonarr: root folder & SAB client =======
echo
echo "Configuring Sonarr root folder and SAB download client ..."
# Detect URL Base (if any)
SONARR_BASE="$SONARR_PUBLIC"
if sys="$(api_call GET "${SONARR_PUBLIC}/api/v3/system/status" "$HDR_SONARR" || true)"; then
  base_url="$(jq -r '.urlBase // ""' <<<"$sys")"
  if [ -n "$base_url" ] && [ "$base_url" != "/" ]; then
    SONARR_BASE="${SONARR_PUBLIC%/}/${base_url#/}"
    echo "Detected Sonarr URL Base: $base_url → using $SONARR_BASE"
  fi
fi

root_json="$(api_call GET "${SONARR_BASE}/api/v3/rootFolder" "$HDR_SONARR")"
if ! jq -e --arg p1 "$TV_ROOT" --arg p2 "${TV_ROOT%/}/" '.[] | select(.path==$p1 or .path==$p2)' >/dev/null <<<"$root_json"; then
  api_call POST "${SONARR_BASE}/api/v3/rootFolder" "$HDR_SONARR" \
    "$(jq -nc --arg path "$TV_ROOT" '{path:$path, accessible:true}')" >/dev/null
fi

dl_clients="$(api_call GET "${SONARR_BASE}/api/v3/downloadclient" "$HDR_SONARR")"
if ! jq -e '.[] | select(.implementation=="Sabnzbd")' >/dev/null <<<"$dl_clients"; then
  # Use host LAN IP to avoid SAB host whitelist issues
  payload="$(jq -nc \
    --arg host "$SAB_HOST" \
    --argjson port "$SAB_PORT" \
    --arg sabkey "$SAB_API_KEY" \
    '{
       enable:true, name:"sabnzbd", protocol:"usenet",
       implementation:"Sabnzbd", configContract:"SabnzbdSettings",
       fields:[
         {name:"host", value:$host},
         {name:"port", value:$port},
         {name:"apiKey", value:$sabkey},
         {name:"username", value:""},
         {name:"password", value:""},
         {name:"tvCategory", value:"tv"},
         {name:"useSsl", value:false},
         {name:"urlBase", value:""},
         {name:"removeCompletedDownloads", value:true},
         {name:"recentTvPriority", value:0},
         {name:"olderTvPriority", value:0}
       ]
     }')"
  if ! api_call POST "${SONARR_BASE}/api/v3/downloadclient" "$HDR_SONARR" "$payload" >/dev/null; then
    echo "Retrying Sonarr SAB client using 'category' key ..." >&2
    payload="$(jq -nc \
      --arg host "$SAB_HOST" \
      --argjson port "$SAB_PORT" \
      --arg sabkey "$SAB_API_KEY" \
      '{
         enable:true, name:"sabnzbd", protocol:"usenet",
         implementation:"Sabnzbd", configContract:"SabnzbdSettings",
         fields:[
           {name:"host", value:$host},
           {name:"port", value:$port},
           {name:"apiKey", value:$sabkey},
           {name:"username", value:""},
           {name:"password", value:""},
           {name:"category", value:"tv"},
           {name:"useSsl", value:false},
           {name:"urlBase", value:""},
           {name:"removeCompletedDownloads", value:true}
         ]
       }')"
    api_call POST "${SONARR_BASE}/api/v3/downloadclient" "$HDR_SONARR" "$payload" >/dev/null
  fi
fi

api_call PUT "${SONARR_BASE}/api/v3/config/downloadclient" "$HDR_SONARR" \
  '{"completedDownloadHandling":{"enable":true,"redownloadFailed":true}}' >/dev/null
echo "Sonarr configured."

# ======= Radarr: root folder & SAB client =======
echo
echo "Configuring Radarr root folder and SAB download client ..."
root_json="$(api_call GET "${RADARR_PUBLIC}/api/v3/rootFolder" "$HDR_RADARR")"
if ! jq -e --arg p1 "$MOVIES_ROOT" --arg p2 "${MOVIES_ROOT%/}/" '.[] | select(.path==$p1 or .path==$p2)' >/dev/null <<<"$root_json"; then
  api_call POST "${RADARR_PUBLIC}/api/v3/rootFolder" "$HDR_RADARR" \
    "$(jq -nc --arg path "$MOVIES_ROOT" '{path:$path, accessible:true}')" >/dev/null
fi

dl_clients="$(api_call GET "${RADARR_PUBLIC}/api/v3/downloadclient" "$HDR_RADARR")"
if ! jq -e '.[] | select(.implementation=="Sabnzbd")' >/dev/null <<<"$dl_clients"; then
  payload="$(jq -nc \
    --arg host "$SAB_HOST" \
    --argjson port "$SAB_PORT" \
    --arg sabkey "$SAB_API_KEY" \
    '{
       enable:true, name:"sabnzbd", protocol:"usenet",
       implementation:"Sabnzbd", configContract:"SabnzbdSettings",
       fields:[
         {name:"host", value:$host},
         {name:"port", value:$port},
         {name:"apiKey", value:$sabkey},
         {name:"username", value:""},
         {name:"password", value:""},
         {name:"category", value:"movies"},
         {name:"useSsl", value:false},
         {name:"urlBase", value:""},
         {name:"removeCompletedDownloads", value:true}
       ]
     }')"
  api_call POST "${RADARR_PUBLIC}/api/v3/downloadclient" "$HDR_RADARR" "$payload" >/dev/null
fi

api_call PUT "${RADARR_PUBLIC}/api/v3/config/downloadclient" "$HDR_RADARR" \
  '{"completedDownloadHandling":{"enable":true,"redownloadFailed":true}}' >/dev/null
echo "Radarr configured."

# ======= Prowlarr: register Sonarr & Radarr (use INTERNAL URLs) =======
echo
echo "Registering Sonarr/Radarr inside Prowlarr ..."
apps="$(api_call GET "${PROWLARR_PUBLIC}/api/v1/applications" "$HDR_PROWLARR")"

if ! jq -e '.[] | select(.name=="Sonarr")' >/dev/null <<<"$apps"; then
  payload="$(jq -nc --arg base "$SONARR_INTERNAL" --arg key "$SONARR_API_KEY" '{
    name:"Sonarr", implementation:"Sonarr", configContract:"SonarrSettings",
    syncLevel:"fullSync",
    fields:[ {name:"apiKey",value:$key}, {name:"baseUrl",value:$base}, {name:"shouldSyncCategories",value:true}, {name:"tags",value:[]} ]
  }')"
  api_call POST "${PROWLARR_PUBLIC}/api/v1/applications" "$HDR_PROWLARR" "$payload" >/dev/null
fi

if ! jq -e '.[] | select(.name=="Radarr")' >/dev/null <<<"$apps"; then
  payload="$(jq -nc --arg base "$RADARR_INTERNAL" --arg key "$RADARR_API_KEY" '{
    name:"Radarr", implementation:"Radarr", configContract:"RadarrSettings",
    syncLevel:"fullSync",
    fields:[ {name:"apiKey",value:$key}, {name:"baseUrl",value:$base}, {name:"shouldSyncCategories",value:true}, {name:"tags",value:[]} ]
  }')"
  api_call POST "${PROWLARR_PUBLIC}/api/v1/applications" "$HDR_PROWLARR" "$payload" >/dev/null
fi

echo
echo "All set! ✅  Sonarr/Radarr roots + SAB clients wired (using $SAB_HOST:$SAB_PORT), Prowlarr apps registered."
echo "Now add your indexers in Prowlarr; they'll sync automatically."
