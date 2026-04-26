#!/bin/bash
set -e

# fastclaw entrypoint script
# This script is called by the Docker container's ENTRYPOINT
#
# Environment variables (set by hiclaw-controller via create-worker.sh):
#   HICLAW_WORKER_NAME    - Worker name (required, falls back to WORKER_NAME)
#   HICLAW_DEFAULT_MODEL  - LLM model ID (required, falls back to LLM_MODEL)
#   HICLAW_RUNTIME_CONFIG - JSON string with runtime-specific config (falls back to RUNTIME_CONFIG)
#   HICLAW_MATRIX_URL     - Matrix homeserver URL
#   HICLAW_WORKER_MATRIX_TOKEN - Matrix access token
#   HICLAW_AI_GATEWAY_URL - Higress AI gateway URL
#   HICLAW_WORKER_GATEWAY_KEY - Higress consumer auth token
#   HICLAW_FS_ENDPOINT    - MinIO endpoint (required for mc alias)
#   HICLAW_FS_ACCESS_KEY  - MinIO access key
#   HICLAW_FS_SECRET_KEY  - MinIO secret key
#   MINIO_FS_DIR          - MinIO filesystem directory

log() {
    echo "[fastclaw $(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Resolve env vars with fallback to legacy names
WORKER_NAME="${HICLAW_WORKER_NAME:-${WORKER_NAME:-}}"
MODEL="${HICLAW_DEFAULT_MODEL:-${LLM_MODEL:-}}"
RUNTIME_CFG="${HICLAW_RUNTIME_CONFIG:-${RUNTIME_CONFIG:-}}"
FS_ENDPOINT="${HICLAW_FS_ENDPOINT:-}"
FS_ACCESS_KEY="${HICLAW_FS_ACCESS_KEY:-}"
FS_SECRET_KEY="${HICLAW_FS_SECRET_KEY:-}"

# Validate required environment variables
if [ -z "$WORKER_NAME" ]; then
    echo "ERROR: HICLAW_WORKER_NAME (or WORKER_NAME) environment variable is required"
    exit 1
fi

if [ -z "$MODEL" ]; then
    echo "ERROR: HICLAW_DEFAULT_MODEL (or LLM_MODEL) environment variable is required"
    exit 1
fi

# Export resolved values for Python script
export HICLAW_WORKER_NAME="$WORKER_NAME"
export HICLAW_DEFAULT_MODEL="$MODEL"
if [ -n "$RUNTIME_CFG" ]; then
    export HICLAW_RUNTIME_CONFIG="$RUNTIME_CFG"
    log "Runtime config provided"
fi

# Set timezone from TZ env var
if [ -n "${TZ}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
    ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime
    echo "${TZ}" > /etc/timezone
    log "Timezone set to ${TZ}"
fi

# ============================================================
# Step 1: Configure mc alias for centralized file system
# ============================================================
if [ -n "${FS_ENDPOINT}" ] && [ -n "${FS_ACCESS_KEY}" ] && [ -n "${FS_SECRET_KEY}" ]; then
    log "Configuring mc alias for MinIO..."
    mc alias set hiclaw "${FS_ENDPOINT}" "${FS_ACCESS_KEY}" "${FS_SECRET_KEY}" 2>/dev/null || {
        log "WARNING: mc alias set failed; file sync will not be available"
    }
else
    log "WARNING: MinIO credentials not set (HICLAW_FS_ENDPOINT/ACCESS_KEY/SECRET_KEY); skipping mc configuration"
fi

# ============================================================
# Step 2: Wait for MinIO filesystem and pull config
# ============================================================
HICLAW_ROOT="${MINIO_FS_DIR:-/root/hiclaw-fs}"
WORKSPACE="${HICLAW_ROOT}/agents/${WORKER_NAME}"

mkdir -p "${WORKSPACE}"

log "Waiting for MinIO filesystem..."
for i in $(seq 1 30); do
    if [ -d "${HICLAW_ROOT}" ]; then
        # Try to pull config from MinIO if mc is configured
        if mc alias list 2>/dev/null | grep -q hiclaw; then
            log "Pulling worker config from MinIO..."
            mc mirror "hiclaw/agents/${WORKER_NAME}/" "${WORKSPACE}/" --overwrite 2>/dev/null || true
        fi
        log "MinIO filesystem is ready"
        break
    fi
    if [ "$i" -eq 30 ]; then
        log "WARNING: MinIO filesystem not found, continuing anyway"
    fi
    sleep 1
done

# ============================================================
# Step 3: Start file sync (local -> remote, every 10s)
# ============================================================
if mc alias list 2>/dev/null | grep -q hiclaw; then
    (
        while true; do
            CHANGED=$(find "${WORKSPACE}/" -type f -newermt "10 seconds ago" 2>/dev/null | head -1)
            if [ -n "${CHANGED}" ]; then
                mc mirror "${WORKSPACE}/" "hiclaw/agents/${WORKER_NAME}/" --overwrite \
                    --exclude "fastclaw.json" \
                    --exclude ".cache/**" --exclude "*.lock" 2>/dev/null || true
            fi
            sleep 5
        done
    ) &
    log "Local->Remote sync started (PID: $!)"
fi

# ============================================================
# Step 4: Launch fastclaw Python worker
# ============================================================
log "Launching fastclaw Python worker: ${WORKER_NAME} (model: ${MODEL})"
exec python3 /app/worker.py
