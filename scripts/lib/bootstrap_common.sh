#!/usr/bin/env bash

# Common helpers for mediaserver bootstrap scripts.
# Designed to be sourced from scripts/bootstrap-mediaserver.sh.

if [[ -n "${BOOTSTRAP_COMMON_SOURCED:-}" ]]; then
  return 0
fi
BOOTSTRAP_COMMON_SOURCED=1

bootstrap::set_curl_defaults() {
  local max_time="${1:-8}"
  local connect_timeout="${2:-4}"
  BOOTSTRAP_CURL_COMMON=(-sS --fail-with-body --max-time "$max_time" --connect-timeout "$connect_timeout")
}

bootstrap::set_curl_defaults

bootstrap::need_bin() {
  local bin="$1"
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Missing dependency: $bin" >&2
    exit 1
  fi
}

bootstrap::wait_http() {
  local url="$1" name="$2" max_attempts="${3:-90}"
  echo "Waiting for $name at $url ..."
  local code=""
  for _ in $(seq 1 "$max_attempts"); do
    code="$(curl -s -o /dev/null -w "%{http_code}" "$url" || true)"
    case "$code" in
      200|301|302|401)
        echo "OK: $name is up (HTTP $code)"
        return 0
        ;;
    esac
    sleep 2
  done
  echo "ERROR: $name not responding at $url (last HTTP code: $code)" >&2
  exit 1
}

bootstrap::prompt_secret() {
  local var="$1" prompt="$2" silent="${3:-false}"
  if [ -n "${!var:-}" ]; then
    return 0
  fi
  local value=""
  if [[ "$silent" == true ]]; then
    read -r -s -p "$prompt: " value
    echo
  else
    read -r -p "$prompt: " value
  fi
  printf -v "$var" '%s' "$value"
  export "$var"
}

bootstrap::curl_get() {
  local header="$1" url="$2"
  local args=("${BOOTSTRAP_CURL_COMMON[@]}")
  if [ -n "$header" ]; then
    args+=(-H "$header")
  fi
  args+=("$url")
  curl "${args[@]}"
}

bootstrap::curl_post() {
  local header="$1" body="$2" url="$3"
  local args=("${BOOTSTRAP_CURL_COMMON[@]}" -X POST -H "Content-Type: application/json")
  if [ -n "$header" ]; then
    args+=(-H "$header")
  fi
  args+=(-d "$body" "$url")
  curl "${args[@]}"
}

bootstrap::curl_put() {
  local header="$1" body="$2" url="$3"
  local args=("${BOOTSTRAP_CURL_COMMON[@]}" -X PUT -H "Content-Type: application/json")
  if [ -n "$header" ]; then
    args+=(-H "$header")
  fi
  args+=(-d "$body" "$url")
  curl "${args[@]}"
}

bootstrap::curl_get_params() {
  local url="$1"
  shift
  curl "${BOOTSTRAP_CURL_COMMON[@]}" --get "$url" "$@"
}
