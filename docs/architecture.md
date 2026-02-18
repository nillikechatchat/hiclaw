# HiClaw Architecture

## System Overview

HiClaw is an Agent Teams system that enables multiple AI Agents to collaborate via instant messaging (Matrix protocol) with human oversight.

```mermaid
graph TB
    subgraph Manager Container
        HG[Higress AI Gateway<br/>:8080]
        HC[Higress Console<br/>:8001]
        TW[Tuwunel Matrix Server<br/>:6167]
        EW[Element Web<br/>:8088]
        MO[MinIO<br/>:9000 / :9001]
        MA[Manager Agent<br/>OpenClaw]
        MC[mc mirror]
    end

    subgraph Worker Container - Alice
        WA[Worker Agent<br/>OpenClaw]
        WMC[mc]
        WMP[mcporter]
    end

    subgraph Worker Container - Bob
        WB[Worker Agent<br/>OpenClaw]
        WMC2[mc]
        WMP2[mcporter]
    end

    Human[Human Admin<br/>Browser] -->|Element Web| HG
    Human -->|IM| TW
    
    HG -->|Matrix| TW
    HG -->|Files| MO
    HG -->|LLM API| LLM[LLM Provider]
    HG -->|MCP| GitHub[GitHub API]
    
    MA -->|Matrix| TW
    MA -->|Higress API| HC
    MC <-->|sync| MO

    WA -->|Matrix via Gateway| HG
    WMC <-->|file sync| MO
    WMP -->|MCP tools| HG
    
    WB -->|Matrix via Gateway| HG
    WMC2 <-->|file sync| MO
    WMP2 -->|MCP tools| HG
```

## Component Details

### AI Gateway (Higress)

Higress serves as the unified entry point for all external access:

| Port | Service | Purpose |
|------|---------|---------|
| 8080 | Gateway | Reverse proxy for all domain-based routing |
| 8001 | Console | Management API (Session Cookie auth) |

**Routes configured:**
- `matrix-local.hiclaw.io` -> Tuwunel (port 6167) - Matrix Homeserver
- `matrix-client-local.hiclaw.io` -> Element Web (port 8088) - IM web client
- `fs-local.hiclaw.io` -> MinIO (port 9000) - HTTP file system (auth required)
- `llm-local.hiclaw.io` -> AI Provider - LLM proxy (auth required)
- MCP Server routes - Auto-generated for each MCP server

### Matrix Homeserver (Tuwunel)

Tuwunel is a high-performance Matrix Homeserver (conduwuit fork):
- Runs on port 6167
- Manages all IM communication between Human, Manager, and Workers
- Uses `CONDUWUIT_` environment variable prefix
- Single-step registration with token (no UIAA flow)

### HTTP File System (MinIO)

MinIO provides centralized file storage accessible via HTTP:
- Port 9000 (API) and 9001 (Console)
- `mc mirror --watch` provides real-time local<->remote sync
- All Agent configs, task briefs, and results stored here

### Manager Agent (OpenClaw)

The Manager Agent coordinates the entire team:
- Receives tasks from human via Matrix DM
- Creates Workers (Matrix accounts + Higress consumers + config files)
- Assigns and tracks tasks
- Runs heartbeat checks every 15 minutes
- Manages credentials with dual-key sliding window rotation

### Worker Agent (OpenClaw)

Workers are lightweight, stateless containers:
- Pull all config from MinIO on startup
- Communicate via Matrix Rooms (Human + Manager + Worker in each Room)
- Use mcporter CLI to call MCP Server tools (GitHub, etc.)
- Can be destroyed and recreated without losing state
- Manager can create Workers directly via the host container runtime socket (Docker/Podman), or provide a `docker run` command for manual/remote deployment

## Security Model

```
┌──────────────────────────────────────┐
│            Higress Gateway           │
│   Consumer key-auth (BEARER token)   │
│                                      │
│  manager: full access                │
│  worker-alice: AI + FS + MCP(github) │
│  worker-bob:   AI + FS              │
└──────────────────────────────────────┘
```

- Each Worker has a unique Consumer with key-auth BEARER token
- Manager controls which routes and MCP Servers each Worker can access
- External API credentials (GitHub PAT, etc.) stored centrally in MCP Server config
- Workers never see external API credentials directly

## Communication Model

All communication happens in Matrix Rooms with Human-in-the-Loop:

```
Room: "Worker: Alice"
├── Members: @admin, @manager, @alice
├── Manager assigns task -> visible to all
├── Alice reports progress -> visible to all
├── Human can intervene anytime -> visible to all
└── No hidden communication between Manager and Worker
```

## File System Layout

```
MinIO bucket: hiclaw-storage/
├── agents/
│   ├── manager/         # Manager config + skills
│   │   ├── SOUL.md
│   │   ├── AGENTS.md
│   │   ├── HEARTBEAT.md
│   │   ├── openclaw.json
│   │   └── skills/
│   ├── alice/           # Worker Alice config
│   │   ├── SOUL.md
│   │   ├── openclaw.json
│   │   └── mcporter-servers.json
│   └── bob/             # Worker Bob config
├── shared/
│   ├── tasks/           # Task briefs, metadata, and results
│   │   └── task-{id}/
│   │       ├── meta.json    # Task metadata (assigned_to, status, timestamps)
│   │       ├── brief.md     # Task description (written by Manager)
│   │       └── result.md    # Task result (written by Worker)
│   └── knowledge/       # Shared reference materials
├── manager/
│   └── credentials/     # Manager credential records
└── workers/             # Worker work products
```
