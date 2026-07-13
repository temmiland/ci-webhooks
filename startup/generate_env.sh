#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="/app/environment.json"
ENV_FILE="/output/.env"

# Function to read a key from JSON
get_json() {
    jq -r ".$1" "$CONFIG_FILE"
}

# Fail fast on missing required keys instead of writing the literal "null"
require() {
    if [ -z "$2" ] || [ "$2" == "null" ]; then
        echo "ERROR: required key '$1' is missing in $CONFIG_FILE" >&2
        exit 1
    fi
}

# Read values from JSON
NETWORK=$(get_json network)
CI_PORT=$(get_json ci_port)
CI_DOMAIN=$(get_json ci_domain)
PROJECTS_ROOT=$(get_json projects_root)
CI_KEY=$(get_json ci_key)

require network "$NETWORK"
require ci_port "$CI_PORT"
require ci_domain "$CI_DOMAIN"
require projects_root "$PROJECTS_ROOT"

# Generate secrets on the fly (256-bit, matches README "Best Practices")
if [ -z "$CI_KEY" ] || [ "$CI_KEY" == "null" ]; then
    echo "No CI_KEY provided in $CONFIG_FILE, generating a new one."
    CI_KEY=$(openssl rand -hex 32)
fi

# Write .env
cat > "$ENV_FILE" <<EOF
# Generated from $CONFIG_FILE

TRAEFIK_NETWORK_NAME=$NETWORK
CI_PORT=$CI_PORT
CI_DOMAIN=$CI_DOMAIN
PROJECTS_ROOT=$PROJECTS_ROOT
CI_KEY=$CI_KEY
EOF
