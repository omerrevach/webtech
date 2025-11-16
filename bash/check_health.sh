#!/usr/bin/env bash

# Don't exit on first error here – we want to handle curl failures manually
set -u  # fail on unset variables

URL=${1:-}
TIMEOUT=${2:-20}
INTERVAL=2
ELAPSED=0

if [ -z "$URL" ]; then
  echo "[ERROR] Usage: ./check_health.sh <url> [timeout_seconds]"
  echo "Example: ./check_health.sh http://localhost:8080/healthz 30"
  exit 1
fi

echo "[INFO] Checking health for: $URL"
echo "[INFO] Timeout: ${TIMEOUT}s, Interval: ${INTERVAL}s"

while [ $ELAPSED -lt $TIMEOUT ]; do
  # -s silent, -o discard body, -w print HTTP code
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
  CURL_EXIT_CODE=$?

  if [ $CURL_EXIT_CODE -ne 0 ]; then
    echo "[WARN] curl failed (exit code: $CURL_EXIT_CODE). Retrying..."
  else
    if [ "$HTTP_CODE" = "200" ]; then
      echo "[SUCCESS] Service is healthy (HTTP 200)."
      exit 0
    else
      echo "[WARN] Service not healthy yet (HTTP $HTTP_CODE). Retrying..."
    fi
  fi

  sleep $INTERVAL
  ELAPSED=$((ELAPSED + INTERVAL))
done

echo "[ERROR] Timeout reached after ${TIMEOUT}s. Service is NOT healthy."
exit 1
