#!/bin/bash

# Exit immediately if any command fails
set -e

IMAGE_NAME=${1:-nginx}
PORT=${2:-80}

echo "[INFO] Building Docker image: $IMAGE_NAME (Dockerfile must be in this folder)"

docker build -t "$IMAGE_NAME" .

echo "[INFO] Stopping existing container (if running)..."
if docker ps --format '{{.Names}}' | grep -q "^${IMAGE_NAME}-container$"; then
  docker stop "${IMAGE_NAME}-container" >/dev/null 2>&1 || true
  docker rm "${IMAGE_NAME}-container" >/dev/null 2>&1 || true
fi

echo "[INFO] Starting new container on port $PORT"
docker run -d -p "$PORT:80" --name "${IMAGE_NAME}-container" "$IMAGE_NAME"

RUN_EXIT_CODE=$?

if [ $RUN_EXIT_CODE -ne 0 ]; then
  echo "[ERROR] Failed to start container (exit code: $RUN_EXIT_CODE)"
  exit 1
fi

echo "[SUCCESS] Container is running."
echo "[INFO] Open this in your browser: http://localhost:${PORT}"
