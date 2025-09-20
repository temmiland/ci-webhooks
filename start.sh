#!/usr/bin/env bash
set -euo pipefail

# Check for Dependencies
for cmd in docker "docker compose"; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ $cmd is not installed. Please install $cmd and try again."
        exit 1
    fi
done

# Paths
HOST_STARTUP_DIR="$PWD/startup"
HOST_CONFIG_FILE="$PWD/config/environment.json"
HOST_REPOS_FILE="$PWD/config/repos.json"
OUTPUT_DIR="$PWD"

# Check required files
for file in "$HOST_CONFIG_FILE" "$HOST_REPOS_FILE"; do
    if [[ ! -f "$file" ]]; then
        echo "❌ Required file '$file' not found. Aborting."
        exit 1
    fi
done

# Create a temporary directory for Docker build
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Copy necessary files into temp directory
cp "$HOST_STARTUP_DIR/generate_env.sh" "$TMP_DIR/"
cp "$HOST_CONFIG_FILE" "$TMP_DIR/environment.json"
cp "$HOST_REPOS_FILE" "$TMP_DIR/repos.json"

# Build Docker image temporarily
IMAGE_ID=$(docker build -q -f "$HOST_STARTUP_DIR/Dockerfile" "$TMP_DIR")

# Run the container to generate .env
docker run --rm \
  -v "$TMP_DIR":/app \
  -v "$OUTPUT_DIR":/output \
  -u $(id -u):$(id -g) \
  "$IMAGE_ID"
rm -fr "$TMP_DIR/"

echo "✅ Creation of .env file successful."

# Check if .env exists
if [[ ! -f ".env" ]]; then
    echo "❌ .env file not found, aborting application startup."
    exit 1
fi

# Start application with Docker Compose
docker compose up -d --build
