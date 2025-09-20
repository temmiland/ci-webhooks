#!/usr/bin/env bash
set -euo pipefail

REPO_NAME=${1:-}

if [ -z "$REPO_NAME" ]; then
    echo '{"status":"error","message":"No repository name provided. Exiting."}'
    exit 1
fi

LOG_FILE="/opt/webhook/logs/deploy_$REPO_NAME.log"
STATUS_FILE="/opt/webhook/status/deploy_$REPO_NAME.json"

REPO=$(/usr/bin/jq -c --arg name "$REPO_NAME" '.repos[] | select(.name==$name)' /opt/webhook/repos.json || true)

if [ -z "$REPO" ]; then
    echo '{"status":"error","message":"Repo $REPO_NAME not found in repos.json"}' > "$STATUS_FILE"
    exit 1
fi

PATH=$(echo "$REPO" | /usr/bin/jq -r '.path')
BRANCH=$(echo "$REPO" | /usr/bin/jq -r '.branch')
SCRIPT=$(echo "$REPO" | /usr/bin/jq -r '.deploy_script')

if [ ! -d "$PATH" ]; then
    echo '{"status":"error","message":"Repo path $PATH does not exist"}' > "$STATUS_FILE"
    exit 1
fi

echo '{"status":"running","message":"Deployment is running"}' > "$STATUS_FILE"

{
    echo "Deploying $REPO_NAME from $BRANCH..."
    cd "$PATH"

    git fetch origin "$BRANCH"
    git reset --hard "origin/$BRANCH"

    if [ -x "$SCRIPT" ]; then
        bash "$SCRIPT"
    else
        echo "Deployment script $SCRIPT not found or not executable"
        exit 1
    fi

    echo '{"status":"success","message":"Deployment successful"}' > "$STATUS_FILE"
} || {
    echo '{"status":"error","message":"Deployment failed"}' > "$STATUS_FILE"
}
