#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

info() {
  printf '\n\033[1;34m%s\033[0m\n' "$1"
}

warn() {
  printf '\n\033[1;33m%s\033[0m\n' "$1" >&2
}

info "Running git fsck --full"
git fsck --full

if command -v trufflehog >/dev/null 2>&1; then
  info "Scanning repository for secrets with trufflehog"
  trufflehog filesystem \
    --no-update \
    --only-verified \
    --fail \
    --json \
    --exclude-paths .trufflehog-exclude \
    .
else
  warn "trufflehog not found; skipping secret scan. Install it to mirror CI checks."
fi

compose_cmd=()
if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    compose_cmd=(docker compose)
  fi
fi

if [ ${#compose_cmd[@]} -eq 0 ] && command -v docker-compose >/dev/null 2>&1; then
  compose_cmd=(docker-compose)
fi

if [ ${#compose_cmd[@]} -eq 0 ]; then
  warn "Docker Compose CLI not available; skipping compose validation. Run inside a Docker-enabled environment to complete this step."
else
  info "Validating compose.yml"
  "${compose_cmd[@]}" -f compose.yml config >/dev/null

  info "Validating homepage-stack.yml"
  "${compose_cmd[@]}" -f homepage-stack.yml config >/dev/null
fi

info "Repository maintenance checks completed successfully."
