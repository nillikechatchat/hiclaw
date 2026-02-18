# Worker Guide

Guide for deploying, managing, and troubleshooting HiClaw Worker Agents.

## Overview

Workers are lightweight, stateless containers that:
- Connect to the Manager via Matrix for task communication
- Sync configuration from centralized MinIO storage
- Use AI Gateway for LLM access
- Use mcporter CLI for MCP Server tool calls (GitHub, etc.)

## Installation

Workers are created by the Manager Agent. The Manager handles all infrastructure setup (Matrix account, Higress consumer, config files, etc.) and can either create the Worker container directly or provide a command for manual execution.

### Method 1: Direct Creation (Recommended for Local Development)

If the Manager has access to the host's container runtime socket (default when using `make install`), it can create Worker containers directly:

1. Tell Manager: "Create a new Worker named alice for frontend dev. Create it directly."
2. Manager creates all infrastructure and starts the container automatically
3. No manual steps needed

### Method 2: Docker Run Command (for Remote Deployment)

If the Manager doesn't have socket access, it will reply with a `docker run` command:

1. Tell Manager: "Create a new Worker named alice for frontend dev"
2. Manager creates infrastructure and provides a `docker run` command
3. Copy and run the command on the target host:

```bash
docker run -d --name hiclaw-worker-alice \
  -e HICLAW_WORKER_NAME=alice \
  -e HICLAW_FS_ENDPOINT=http://<MANAGER_HOST>:9000 \
  -e HICLAW_FS_ACCESS_KEY=<ACCESS_KEY> \
  -e HICLAW_FS_SECRET_KEY=<SECRET_KEY> \
  hiclaw/worker-agent:latest
```

The Manager will provide all the specific values in its reply.

## Troubleshooting

### Worker won't start

```bash
# Check container logs
docker logs hiclaw-worker-alice

# Common issues:
# - "openclaw.json not found": Manager hasn't created config yet
# - "mc: command not found": Image build issue
# - Connection refused: Manager container not running or ports not exposed
```

### Worker can't connect to Matrix

```bash
# Verify Matrix server is reachable from Worker
docker exec hiclaw-worker-alice curl -sf http://matrix-local.hiclaw.io:8080/_matrix/client/versions

# Check Worker's openclaw.json for correct Matrix config
docker exec hiclaw-worker-alice cat /root/hiclaw-fs/agents/alice/openclaw.json | jq '.channels.matrix'
```

### Worker can't access LLM

```bash
# Test AI Gateway access with Worker's key
docker exec hiclaw-worker-alice curl -sf \
  -H "Authorization: Bearer $(jq -r '.models.providers."hiclaw-gateway".apiKey' /root/hiclaw-fs/agents/alice/openclaw.json)" \
  http://llm-local.hiclaw.io:8080/v1/models

# If 401: Worker's consumer key may have been rotated. Ask Manager to update.
# If 403: Worker may not be authorized for the AI route. Ask Manager to add.
```

### Worker can't access MCP (GitHub)

```bash
# Check if MCP access is authorized
# Ask Manager to verify Worker's MCP permissions

# Test mcporter connectivity
docker exec hiclaw-worker-alice mcporter --transport sse \
  --server-url "http://llm-local.hiclaw.io:8080/mcp/mcp-github/sse" \
  --header "Authorization=Bearer <WORKER_KEY>" \
  call list_repos '{"owner": "test"}'

# If 403: Worker not authorized for this MCP Server. Ask Manager.
```

### Resetting a Worker

```bash
# Stop and remove the container
docker stop hiclaw-worker-alice
docker rm hiclaw-worker-alice

# Then ask Manager to recreate Worker config and start it again
```

## Architecture Details

### Startup Sequence

1. Configure `mc` alias for MinIO access
2. Pull Worker config from MinIO (`agents/<name>/`)
3. Copy skill templates
4. Start bidirectional mc mirror sync
5. Configure mcporter with MCP endpoints
6. Launch OpenClaw

### File Sync

- **Local to Remote**: Real-time via `mc mirror --watch`
- **Remote to Local**: Periodic pull every 5 minutes

### Config Hot-Reload

When Manager updates Worker's config in MinIO:
1. MinIO receives the updated file
2. mc mirror pulls it to Worker's local filesystem (next 5-min cycle, or immediately if Manager pushes)
3. OpenClaw detects file change (~300ms) and hot-reloads config

### Environment Variables

| Variable | Description |
|----------|-------------|
| `HICLAW_WORKER_NAME` | Worker identifier |
| `HICLAW_MATRIX_SERVER` | Matrix Homeserver URL |
| `HICLAW_AI_GATEWAY` | AI Gateway URL |
| `HICLAW_FS_ENDPOINT` | MinIO endpoint URL |
| `HICLAW_FS_ACCESS_KEY` | MinIO access key |
| `HICLAW_FS_SECRET_KEY` | MinIO secret key |
