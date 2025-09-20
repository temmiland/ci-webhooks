#!/usr/bin/env bash
set -euo pipefail

REPO_NAME=${1:-}

if [ -z "$REPO_NAME" ]; then
    echo '{"status":"error","message":"No repository name provided. Exiting."}'
    exit 1
fi

STATUS_FILE="/opt/webhook/status/deploy_$REPO_NAME.json"

if [[ -f "$STATUS_FILE" ]]; then
    cat "$STATUS_FILE"
else
    echo '{"status":"unknown","message":"No status file found for repository '"$REPO_NAME"'.\"}'
fi
