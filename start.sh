#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Paths
# -----------------------------
HOST_STARTUP_DIR="$PWD/startup"
HOST_CONFIG_FILE="$PWD/config/environment.json"
OUTPUT_DIR="$PWD"

# -----------------------------
# Create a temporary directory for Docker build
# -----------------------------
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Copy necessary files into temp directory
cp "$HOST_STARTUP_DIR/generate_env.sh" "$TMP_DIR/"
cp "$HOST_CONFIG_FILE" "$TMP_DIR/environment.json"

# -----------------------------
# Build Docker image temporarily
# -----------------------------
IMAGE_ID=$(docker build -q -f "$HOST_STARTUP_DIR/Dockerfile" "$TMP_DIR")

# -----------------------------
# Run the container to generate .env
# -----------------------------
docker run --rm \
  -v "$TMP_DIR":/app \
  -v "$OUTPUT_DIR":/output \
  -u $(id -u):$(id -g) \
  "$IMAGE_ID"
rm -fr "$TMP_DIR/"

echo "✅ Creation of .env file successful."

# -----------------------------
# Check if .env exists
# -----------------------------
if [[ ! -f ".env" ]]; then
    echo "❌ .env file not found, aborting application startup."
    exit 1
fi

# -----------------------------
# Start docker-compose (optional)
# -----------------------------
# docker-compose up -d
