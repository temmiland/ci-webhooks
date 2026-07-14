#!/usr/bin/env bash
set -euo pipefail

REPO_NAME=${1:-}

if [ -z "$REPO_NAME" ]; then
    echo '{"status":"error","message":"No repository name provided. Exiting."}'
    exit 1
fi

if [[ ! "$REPO_NAME" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo '{"status":"error","message":"Invalid repository name."}'
    exit 1
fi

LOG_FILE="/opt/webhook/logs/deploy_${REPO_NAME}_$(date +%Y_%m_%d).log"
STATUS_FILE="/opt/webhook/status/deploy_$REPO_NAME.json"

REPO=$(jq -c --arg name "$REPO_NAME" '.repos[] | select(.name==$name)' /opt/webhook/repos.json || true)

if [ -z "$REPO" ]; then
    echo "{\"status\":\"error\",\"message\":\"Repo $REPO_NAME not found in repos.json\"}" > "$STATUS_FILE"
    exit 1
fi

REPO_PATH=$(echo "$REPO" | jq -r '.path')
BRANCH=$(echo "$REPO" | jq -r '.branch')
SCRIPT=$(echo "$REPO" | jq -r '.deploy_script')

if [ ! -d "$REPO_PATH" ]; then
    echo "{\"status\":\"error\",\"message\":\"Repo path $REPO_PATH does not exist\"}" > "$STATUS_FILE"
    exit 1
fi

echo '{"status":"running","message":"Deployment is running"}' > "$STATUS_FILE"

# The deploy body must run as its own bash process: inside an `if`/`||`
# context POSIX suppresses errexit for the current shell, so a failing
# `git fetch` or deploy script in an inline block would fall through and
# report success. A child process keeps its own `set -e` intact.
if bash -euo pipefail -c '
    REPO_PATH=$1; BRANCH=$2; SCRIPT=$3
    echo "Deploying from branch $BRANCH..."
    cd "$REPO_PATH"
    pwd
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
' _ "$REPO_PATH" "$BRANCH" "$SCRIPT" 2>&1 | tee -a "$LOG_FILE"
then
    echo '{"status":"success","message":"Deployment successful"}' | tee "$STATUS_FILE"
else
    echo '{"status":"error","message":"Deployment failed"}' | tee "$STATUS_FILE"
fi
