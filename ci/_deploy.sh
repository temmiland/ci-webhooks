#!/usr/bin/env bash
set -euo pipefail

REPO_NAME=${1:-}

if [ -z "$REPO_NAME" ]; then
    echo '{"status":"error","message":"No repository name provided. Exiting."}'
    exit 1
fi

LOG_FILE="/opt/webhook/logs/deploy_$REPO_NAME.log"
STATUS_FILE="/opt/webhook/status/deploy_$REPO_NAME.json"

REPO=$(jq -c --arg name "$REPO_NAME" '.repos[] | select(.name==$name)' /opt/webhook/repos.json || true)

if [ -z "$REPO" ]; then
    echo '{"status":"error","message":"Repo $REPO_NAME not found in repos.json"}' > "$STATUS_FILE"
    exit 1
fi

REPO_PATH=$(echo "$REPO" | jq -r '.path')
BRANCH=$(echo "$REPO" | jq -r '.branch')
SCRIPT=$(echo "$REPO" | jq -r '.deploy_script')

if [ ! -d "$REPO_PATH" ]; then
    echo '{"status":"error","message":"Repo path $REPO_PATH does not exist"}' > "$STATUS_FILE"
    exit 1
fi

echo '{"status":"running","message":"Deployment is running"}' > "$STATUS_FILE"

{
    echo "Deploying $REPO_NAME from $BRANCH..."
    cd "$REPO_PATH"
    pwd

    git config --global --add safe.directory /opt/webhook/projects/"$REPO_NAME"
    git fetch origin "$BRANCH"
    git reset --hard "origin/$BRANCH"

    if [ -x "$SCRIPT" ]; then
        echo "Running deployment script $SCRIPT..."
        bash "$SCRIPT"
    else
        ls -lah
        echo "Deployment script $SCRIPT not found or not executable"
        exit 1
    fi

    echo '{"status":"success","message":"Deployment successful"}' | tee "$STATUS_FILE"
} 2>&1 | tee -a "$LOG_FILE" || {
    echo '{"status":"error","message":"Deployment failed"}' > "$STATUS_FILE"
}
