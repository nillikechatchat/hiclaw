#!/bin/bash
# upgrade-builtins.sh - Upgrade Manager workspace builtin files and sync Worker builtins to MinIO
#
# Called by start-manager-agent.sh on first boot or when image version changes.
# Strategy:
#   - .md files: merge (replace builtin section, preserve user content below end marker)
#   - scripts/ and references/ dirs: always overwrite from image
#   - Worker builtins: sync directly to each registered worker's MinIO workspace
#   - Workers no longer need to pull from shared/builtins/worker/ on startup

set -e

AGENT_SRC="/opt/hiclaw/agent"
WORKSPACE="/root/manager-workspace"
REGISTRY="${WORKSPACE}/workers-registry.json"
IMAGE_VERSION=$(cat "${AGENT_SRC}/.builtin-version" 2>/dev/null || echo "unknown")
MANAGER_RUNTIME="${HICLAW_MANAGER_RUNTIME:-openclaw}"

source /opt/hiclaw/scripts/lib/hiclaw-env.sh
source /opt/hiclaw/scripts/lib/builtin-merge.sh

log() {
    echo "[upgrade-builtins $(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ============================================================
# Step 1: Upgrade Manager workspace .md files (14 files)
# ============================================================
log "Step 1: Upgrading Manager workspace .md files..."

update_builtin_section "${WORKSPACE}/SOUL.md" "${AGENT_SRC}/SOUL.md"
_runtime_manager_dir() {
    case "${MANAGER_RUNTIME}" in
        copaw)     echo "copaw-manager-agent" ;;
        fastclaw)  echo "fastclaw-manager-agent" ;;
        zeroclaw)  echo "zeroclaw-manager-agent" ;;
        nanoclaw)  echo "nanoclaw-manager-agent" ;;
        *)         echo "" ;;
    esac
}

_MANAGER_DIR=$(_runtime_manager_dir)
if [ -n "${_MANAGER_DIR}" ] && [ -f "${AGENT_SRC}/${_MANAGER_DIR}/HEARTBEAT.md" ]; then
    update_builtin_section "${WORKSPACE}/HEARTBEAT.md" "${AGENT_SRC}/${_MANAGER_DIR}/HEARTBEAT.md"
else
    update_builtin_section "${WORKSPACE}/HEARTBEAT.md" "${AGENT_SRC}/HEARTBEAT.md"
fi
if [ -n "${_MANAGER_DIR}" ] && [ -f "${AGENT_SRC}/${_MANAGER_DIR}/AGENTS.md" ]; then
    update_builtin_section "${WORKSPACE}/AGENTS.md" "${AGENT_SRC}/${_MANAGER_DIR}/AGENTS.md"
else
    update_builtin_section "${WORKSPACE}/AGENTS.md" "${AGENT_SRC}/AGENTS.md"
fi
update_builtin_section "${WORKSPACE}/TOOLS.md" "${AGENT_SRC}/TOOLS.md"

_upgrade_skill_md() {
    local src="$1" dst="$2"
    [ -f "${src}" ] || return 0
    mkdir -p "$(dirname "${dst}")"
    case "${MANAGER_RUNTIME}" in
        copaw|fastclaw|zeroclaw|nanoclaw)
            cp "${src}" "${dst}"
            ;;
        *)
            update_builtin_section "${dst}" "${src}"
            ;;
    esac
}

for skill_dir in "${AGENT_SRC}/skills"/*/; do
    skill_name=$(basename "${skill_dir}")
    _upgrade_skill_md "${skill_dir}SKILL.md" "${WORKSPACE}/skills/${skill_name}/SKILL.md"
    log "  Upgraded: skills/${skill_name}/SKILL.md"
done

for skill_dir in "${AGENT_SRC}/worker-skills"/*/; do
    skill_name=$(basename "${skill_dir}")
    _upgrade_skill_md "${skill_dir}SKILL.md" "${WORKSPACE}/worker-skills/${skill_name}/SKILL.md"
    log "  Upgraded: worker-skills/${skill_name}/SKILL.md"
done

# ============================================================
# Step 2: Always overwrite scripts/ and references/ from image
# ============================================================
log "Step 2: Syncing scripts and references..."

for skill_dir in "${AGENT_SRC}/skills"/*/; do
    skill_name=$(basename "${skill_dir}")
    if [ -d "${skill_dir}scripts" ]; then
        mkdir -p "${WORKSPACE}/skills/${skill_name}/scripts"
        cp -r "${skill_dir}scripts/." "${WORKSPACE}/skills/${skill_name}/scripts/"
        find "${WORKSPACE}/skills/${skill_name}/scripts" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
        log "  Synced scripts: skills/${skill_name}/scripts/"
    fi
    if [ -d "${skill_dir}references" ]; then
        mkdir -p "${WORKSPACE}/skills/${skill_name}/references"
        cp -r "${skill_dir}references/." "${WORKSPACE}/skills/${skill_name}/references/"
        log "  Synced references: skills/${skill_name}/references/"
    fi
done

for skill_dir in "${AGENT_SRC}/worker-skills"/*/; do
    skill_name=$(basename "${skill_dir}")
    if [ -d "${skill_dir}scripts" ]; then
        mkdir -p "${WORKSPACE}/worker-skills/${skill_name}/scripts"
        cp -r "${skill_dir}scripts/." "${WORKSPACE}/worker-skills/${skill_name}/scripts/"
        find "${WORKSPACE}/worker-skills/${skill_name}/scripts" -name '*.sh' -exec chmod +x {} + 2>/dev/null || true
        log "  Synced scripts: worker-skills/${skill_name}/scripts/"
    fi
done

# Sync workers-registry.json template if not yet present (never overwrite user data)
if [ ! -f "${WORKSPACE}/workers-registry.json" ]; then
    if [ -f "${AGENT_SRC}/workers-registry.json" ]; then
        cp "${AGENT_SRC}/workers-registry.json" "${WORKSPACE}/workers-registry.json"
        log "  Initialized workers-registry.json"
    fi
fi

# Sync state.json template if not yet present (never overwrite user data)
if [ ! -f "${WORKSPACE}/state.json" ]; then
    if [ -f "${AGENT_SRC}/state.json" ]; then
        cp "${AGENT_SRC}/state.json" "${WORKSPACE}/state.json"
        log "  Initialized state.json"
    fi
fi

# ============================================================
# Step 3: Publish Worker builtin templates to MinIO shared/builtins/worker/
# ============================================================
log "Step 3: Publishing Worker builtins to MinIO..."

if mc alias ls hiclaw > /dev/null 2>&1; then
    ensure_mc_credentials 2>/dev/null || true

    _publish_worker_runtime() {
        local runtime_name="$1"
        local worker_agent_src="${AGENT_SRC}/${runtime_name}"

        [ -d "${worker_agent_src}" ] || return 0

        if [ -f "${worker_agent_src}/AGENTS.md" ]; then
            mc cp "${worker_agent_src}/AGENTS.md" \
                "${HICLAW_STORAGE_PREFIX}/shared/builtins/worker/${runtime_name}/AGENTS.md" 2>/dev/null \
                && log "  Published: shared/builtins/worker/${runtime_name}/AGENTS.md" \
                || log "  WARNING: Failed to publish ${runtime_name} AGENTS.md to MinIO (MinIO may not be ready yet)"
        fi

        if [ -d "${worker_agent_src}/skills" ]; then
            for _skill_dir in "${worker_agent_src}/skills"/*/; do
                [ ! -d "${_skill_dir}" ] && continue
                _skill_name=$(basename "${_skill_dir}")
                mc mirror "${_skill_dir}" \
                    "${HICLAW_STORAGE_PREFIX}/shared/builtins/worker/${runtime_name}/skills/${_skill_name}/" --overwrite 2>/dev/null \
                    && log "  Published: shared/builtins/worker/${runtime_name}/skills/${_skill_name}/" \
                    || log "  WARNING: Failed to publish builtin skill ${runtime_name}/${_skill_name} to MinIO"
            done
        fi
    }

    for _runtime in worker-agent copaw-worker-agent fastclaw-worker-agent zeroclaw-worker-agent nanoclaw-worker-agent; do
        _publish_worker_runtime "${_runtime}"
    done

    # Publish all worker-skills directories to builtins so Workers can refresh assigned skills
    for _skill_dir in "${AGENT_SRC}/worker-skills"/*/; do
        _skill_name=$(basename "${_skill_dir}")
        mc mirror "${_skill_dir}" \
            "${HICLAW_STORAGE_PREFIX}/shared/builtins/worker/skills/${_skill_name}/" --overwrite 2>/dev/null \
            && log "  Published: shared/builtins/worker/skills/${_skill_name}/" \
            || log "  WARNING: Failed to publish worker-skill ${_skill_name} to MinIO"
    done
else
    log "  Skipping MinIO publish (mc not configured)"
fi

# ============================================================
# Step 4: Sync builtins to all registered workers' MinIO workspaces
# This ensures workers get builtin updates directly in their workspace,
# eliminating the need for workers to pull from shared/builtins/worker/ on startup.
# ============================================================
log "Step 4: Syncing builtins to registered workers' workspaces..."

if [ -d "${AGENT_SRC}/worker-agent" ] && mc alias ls hiclaw > /dev/null 2>&1; then
    ensure_mc_credentials 2>/dev/null || true
    # Get list of registered workers
    REGISTERED_WORKERS=""
    if [ -f "${REGISTRY}" ]; then
        REGISTERED_WORKERS=$(jq -r '.workers | keys[]' "${REGISTRY}" 2>/dev/null || true)
    fi

    if [ -n "${REGISTERED_WORKERS}" ]; then
        for _worker_name in ${REGISTERED_WORKERS}; do
            [ -z "${_worker_name}" ] && continue
            log "  Syncing builtins to worker: ${_worker_name}"

            # Determine agent source based on role and runtime
            _worker_role=$(jq -r --arg w "${_worker_name}" '.workers[$w].role // "worker"' "${REGISTRY}" 2>/dev/null || echo "worker")
            _worker_runtime=$(jq -r --arg w "${_worker_name}" '.workers[$w].runtime // "openclaw"' "${REGISTRY}" 2>/dev/null || echo "openclaw")
            if [ "${_worker_role}" = "team_leader" ] && [ -d "${AGENT_SRC}/team-leader-agent" ]; then
                _worker_agent_src="${AGENT_SRC}/team-leader-agent"
            else
                case "${_worker_runtime}" in
                    copaw)    _worker_agent_src="${AGENT_SRC}/copaw-worker-agent" ;;
                    fastclaw) _worker_agent_src="${AGENT_SRC}/fastclaw-worker-agent" ;;
                    zeroclaw) _worker_agent_src="${AGENT_SRC}/zeroclaw-worker-agent" ;;
                    nanoclaw) _worker_agent_src="${AGENT_SRC}/nanoclaw-worker-agent" ;;
                    *)        _worker_agent_src="${AGENT_SRC}/worker-agent" ;;
                esac
            fi

            # Merge AGENTS.md (preserve user content after builtin-end marker)
            update_builtin_section_minio \
                "${HICLAW_STORAGE_PREFIX}/agents/${_worker_name}/AGENTS.md" \
                "${_worker_agent_src}/AGENTS.md" \
                && log "    Merged AGENTS.md" \
                || log "    WARNING: Failed to merge AGENTS.md"

            # Push all builtin skills from runtime-specific agent dir
            if [ -d "${_worker_agent_src}/skills" ]; then
                for _skill_dir in "${_worker_agent_src}/skills"/*/; do
                    [ ! -d "${_skill_dir}" ] && continue
                    _skill_name=$(basename "${_skill_dir}")
                    mc mirror "${_skill_dir}" \
                        "${HICLAW_STORAGE_PREFIX}/agents/${_worker_name}/skills/${_skill_name}/" --overwrite 2>/dev/null \
                        && log "    Updated builtin skill: ${_skill_name}" \
                        || log "    WARNING: Failed to sync builtin skill ${_skill_name}"
                done
            fi

            # Push assigned worker-skills (on-demand skills from registry)
            for _skill_name in $(jq -r --arg w "${_worker_name}" \
                '.workers[$w].skills // [] | .[]' "${REGISTRY}" 2>/dev/null); do
                [ -z "${_skill_name}" ] && continue

                _skill_src="${WORKSPACE}/worker-skills/${_skill_name}"
                if [ -d "${_skill_src}" ]; then
                    mc mirror "${_skill_src}/" \
                        "${HICLAW_STORAGE_PREFIX}/agents/${_worker_name}/skills/${_skill_name}/" --overwrite 2>/dev/null \
                        && log "    Updated assigned skill: ${_skill_name}" \
                        || log "    WARNING: Failed to sync assigned skill ${_skill_name}"
                fi
            done
        done
        log "  Synced builtins to $(echo "${REGISTERED_WORKERS}" | wc -w) worker(s)"
    else
        log "  No workers registered, skipping sync"
    fi
else
    log "  Skipping worker sync (worker-agent dir not found or mc not configured)"
fi

# ============================================================
# Step 5: Write installed version
# ============================================================
echo "${IMAGE_VERSION}" > "${WORKSPACE}/.builtin-version"
log "Step 5: Installed version: ${IMAGE_VERSION}"

# ============================================================
# Step 6: Mark that workers need builtin update notification
# ============================================================
# Check if any workers are registered; if so, mark for post-startup notification
if [ -f "${REGISTRY}" ] && jq -e '.workers | length > 0' "${REGISTRY}" > /dev/null 2>&1; then
    touch "${WORKSPACE}/.upgrade-pending-worker-notify"
    log "Step 6: Marked for worker skill notification (workers registered)"
else
    log "Step 6: No workers registered, skipping notification mark"
fi

log "Upgrade complete (version: ${IMAGE_VERSION})"
