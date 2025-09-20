#!/usr/bin/env bash
set -euo pipefail

REPO_NAME=${1:-}

if [ -z "$REPO_NAME" ]; then
    echo '{"status":"error","message":"No repository name provided. Exiting."}'
    exit 1
fi

LOG_FILE="/opt/webhook/logs/deploy_$REPO_NAME.log"
STATUS_FILE="/opt/webhook/status/deploy_$REPO_NAME.json"

nohup /opt/webhook/_deploy.sh "$REPO_NAME" > "$LOG_FILE" 2>&1 &

RESPONSE='{"status":"started","message":"Deployment started for '"$REPO_NAME"'"}'
echo "$RESPONSE" > "$STATUS_FILE"
echo "$RESPONSE"
