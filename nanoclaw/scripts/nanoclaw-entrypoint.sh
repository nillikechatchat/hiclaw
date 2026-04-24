#!/bin/bash
set -e

# NanoClaw entrypoint script

echo "Starting NanoClaw worker..."

# Validate required environment variables
if [ -z "$WORKER_NAME" ]; then
    echo "ERROR: WORKER_NAME environment variable is required"
    exit 1
fi

if [ -z "$LLM_MODEL" ]; then
    echo "ERROR: LLM_MODEL environment variable is required"
    exit 1
fi

# Export for Node.js script
export WORKER_NAME
export LLM_MODEL

# Check runtime config
if [ -n "$RUNTIME_CONFIG" ]; then
    echo "Runtime config: $RUNTIME_CONFIG"
fi

# Wait for MinIO filesystem
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

# Start NanoClaw worker
echo "Launching NanoClaw Node.js worker..."
exec node /app/src/worker.js
