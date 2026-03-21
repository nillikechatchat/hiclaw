# Changelog (Unreleased)

Record image-affecting changes to `manager/`, `worker/`, `openclaw-base/` here before the next release.

---

## Features

- **AI Gateway Management Skill** — New skill-based plugin for managing AI Gateway. Provides web UI and CLI scripts for Provider management and model assignment for Manager/Workers. Accessible via `manager-local.hiclaw.io:8080`. ([manager/agent/skills/ai-gateway-management/](manager/agent/skills/ai-gateway-management/))
- **Smart AI Gateway Activation** — Replaced fixed 45s sleep with active polling in setup-higress.sh. Detects plugin activation in ~10s instead of waiting the full timeout. ([manager/scripts/init/setup-higress.sh](manager/scripts/init/setup-higress.sh))
- **Auto Model Switch Reload** — update-manager-model.sh now triggers OpenClaw config reload via API after patching openclaw.json, reducing the need for manual restarts. ([manager/agent/skills/model-switch/scripts/update-manager-model.sh](manager/agent/skills/model-switch/scripts/update-manager-model.sh))
- **Worker Sync Retry Mechanism** — update-worker-model.sh now retries Matrix notifications (3 attempts) and waits for worker config sync verification. ([manager/agent/skills/worker-model-switch/scripts/update-worker-model.sh](manager/agent/skills/worker-model-switch/scripts/update-worker-model.sh))

## Changes

- **Higress Manager UI via Gateway** — Manager UI now proxied through AI Gateway at `manager-local.hiclaw.io:8080` with basic-auth, no separate port exposure. Simplified installation (removed port prompt). ([manager/scripts/init/setup-higress.sh](manager/scripts/init/setup-higress.sh), [install/hiclaw-install.sh](install/hiclaw-install.sh), [install/hiclaw-install.ps1](install/hiclaw-install.ps1))
- **Web UI Moved to Skill** — Management UI moved from `configs/higress-manager.html` to `skills/ai-gateway-management/web/index.html` for better modularity. ([manager/scripts/init/start-element-web.sh](manager/scripts/init/start-element-web.sh))
---
