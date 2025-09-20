#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/app/environment.json"
ENV_FILE="/output/.env"

# Function to read a key from JSON
get_json() {
    jq -r ".$1" "$CONFIG_FILE"
}

# Read values from JSON
NETWORK=$(get_json network)
CI_PORT=$(get_json ci_port)
CI_UPDATER_PORT=$(get_json ci_updater_port)
CI_DOMAIN=$(get_json ci_domain)
CI_UPDATER_DOMAIN=$(get_json ci_updater_domain)
PROJECTS_ROOT=$(get_json projects_root)
MAIN_WEBHOOK_DIR=$(get_json main_webhook_dir)

# Write .env
cat > "$ENV_FILE" <<EOF
# Generated from $CONFIG_FILE

NETWORK_NAME=$NETWORK
CI_PORT=$CI_PORT
CI_UPDATER_PORT=$CI_UPDATER_PORT
CI_DOMAIN=$CI_DOMAIN
CI_UPDATER_DOMAIN=$CI_UPDATER_DOMAIN
PROJECTS_ROOT=$PROJECTS_ROOT
MAIN_WEBHOOK_DIR=$MAIN_WEBHOOK_DIR
EOF

echo "✅ .env file generated"
