#!/usr/bin/env bash
# Compatibility wrapper that forwards to the maintained bootstrap script.
SCRIPT_DIR=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "$SCRIPT_DIR/scripts/bootstrap-mediaserver.sh" "$@"
