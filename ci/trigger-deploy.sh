#!/usr/bin/env bash
set -euo pipefail

REPO_NAME=${1:-}
QUEUE_DIR="/opt/webhook/queue"

if [ -z "$REPO_NAME" ]; then
    echo '{"status":"error","message":"No repository name provided. Exiting."}'
    exit 1
fi

if [[ ! "$REPO_NAME" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo '{"status":"error","message":"Invalid repository name."}'
    exit 1
fi

mkdir -p "$QUEUE_DIR"
TMP_FILE=$(mktemp "$QUEUE_DIR/.tmp-XXXXXX")
echo "$REPO_NAME" > "$TMP_FILE"
JOB_NAME=$(basename "$TMP_FILE")
mv "$TMP_FILE" "$QUEUE_DIR/${JOB_NAME#.tmp-}.job"

echo '{"status":"queued","message":"Deployment queued for '"$REPO_NAME"'"}'
