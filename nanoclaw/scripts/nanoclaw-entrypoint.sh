#!/bin/bash
set -e

# NanoClaw entrypoint script

echo "Starting NanoClaw worker..."

# Resolve env vars with HiClaw conventions (HICLAW_* takes priority, fallback to legacy names)
WORKER_NAME="${HICLAW_WORKER_NAME:-${WORKER_NAME:-}}"
LLM_MODEL="${HICLAW_DEFAULT_MODEL:-${LLM_MODEL:-}}"

# Validate required environment variables
if [ -z "$WORKER_NAME" ]; then
    echo "ERROR: HICLAW_WORKER_NAME (or WORKER_NAME) environment variable is required"
    exit 1
fi

if [ -z "$LLM_MODEL" ]; then
    echo "ERROR: HICLAW_DEFAULT_MODEL (or LLM_MODEL) environment variable is required"
    exit 1
fi

# Export for Node.js script
export WORKER_NAME
export LLM_MODEL

# Propagate HiClaw env vars so Node.js can read them
export HICLAW_WORKER_NAME="${WORKER_NAME}"
export HICLAW_DEFAULT_MODEL="${LLM_MODEL}"

# Propagate runtime config
if [ -n "${HICLAW_RUNTIME_CONFIG:-}" ]; then
    export RUNTIME_CONFIG="${HICLAW_RUNTIME_CONFIG}"
elif [ -n "${RUNTIME_CONFIG:-}" ]; then
    export HICLAW_RUNTIME_CONFIG="${RUNTIME_CONFIG}"
fi

# Check runtime config
if [ -n "${RUNTIME_CONFIG:-}" ]; then
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
