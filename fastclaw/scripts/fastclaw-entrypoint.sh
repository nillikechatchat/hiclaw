#!/bin/bash
set -e

# fastclaw entrypoint script
# This script is called by the Docker container's ENTRYPOINT

echo "Starting fastclaw worker..."

# Environment variables (set by hiclaw-controller via create-worker.sh):
# - WORKER_NAME: Worker name
# - LLM_MODEL: LLM model ID
# - RUNTIME_CONFIG: JSON string with runtime-specific config
# - HICLAW_WORKSPACE_DIR: Agent workspace directory
# - MINIO_FS_DIR: MinIO filesystem directory

# Validate required environment variables
if [ -z "$WORKER_NAME" ]; then
    echo "ERROR: WORKER_NAME environment variable is required"
    exit 1
fi

if [ -z "$LLM_MODEL" ]; then
    echo "ERROR: LLM_MODEL environment variable is required"
    exit 1
fi

# Export for Python script
export WORKER_NAME
export LLM_MODEL

# Check if runtime config is provided
if [ -n "$RUNTIME_CONFIG" ]; then
    echo "Runtime config: $RUNTIME_CONFIG"
fi

# Wait for MinIO to be ready (if needed)
echo "Waiting for MinIO filesystem..."
for i in {1..30}; do
    if [ -d "$MINIO_FS_DIR" ]; then
        echo "MinIO filesystem is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "WARNING: MinIO filesystem not found, continuing anyway"
    fi
    sleep 1
done

# Start the fastclaw worker
echo "Launching fastclaw Python worker..."
exec python3 /app/worker.py
