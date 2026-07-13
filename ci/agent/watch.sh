#!/usr/bin/env bash
set -uo pipefail

QUEUE_DIR="/opt/webhook/queue"
STATUS_DIR="/opt/webhook/status"
LOG_DIR="/opt/webhook/logs"
# Max seconds a single deploy may take before it is killed and reported as
# error. Raise this if your deploy scripts run long builds.
DEPLOY_TIMEOUT="${DEPLOY_TIMEOUT:-120}"
# Deploy logs untouched for longer than this are discarded (a log is
# appended to on every deploy, so this means "repo not deployed in N days").
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-7}"

mkdir -p "$QUEUE_DIR"

echo "Deploy agent started, watching $QUEUE_DIR (deploy timeout: ${DEPLOY_TIMEOUT}s, log retention: ${LOG_RETENTION_DAYS}d)"

while true; do
    find "$LOG_DIR" -name '*.log' -mtime "+${LOG_RETENTION_DAYS}" -delete 2>/dev/null

    for job in "$QUEUE_DIR"/*.job; do
        [ -e "$job" ] || continue

        REPO_NAME=$(<"$job")
        rm -f "$job"

        if [[ "$REPO_NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
            if ! timeout "$DEPLOY_TIMEOUT" /opt/webhook/_deploy.sh "$REPO_NAME"; then
                echo "Deploy failed or timed out for $REPO_NAME"
                echo '{"status":"error","message":"Deployment failed or timed out"}' \
                    > "$STATUS_DIR/deploy_${REPO_NAME}.json"
            fi
        else
            echo "Rejected invalid repo name in job file: $job"
        fi
    done
    sleep 1
done
